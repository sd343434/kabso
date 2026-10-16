// v1.3 live discovery / profile payloads shaped exactly like the examples
// in docs/contracts/openapi.yaml, plus deterministic room generators for
// pagination tests and goldens. Test-only (G-26): never import from lib/.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

/// `getLiveConfig` example (hosting off: production today).
Map<String, Object?> liveConfigJson({bool hostingEnabled = false}) => {
  'hostingEnabled': hostingEnabled,
  'heartbeatIntervalSeconds': 15,
  'heartbeatStaleAfterSeconds': 45,
};

/// `listLiveCategories` (the contract's example is empty; a populated list
/// uses the same shape).
Map<String, Object?> liveCategoriesJson([
  List<Map<String, Object?>> data = const [],
]) => {'data': data};

/// `listLiveRooms` `onePage` example room.
Map<String, Object?> liveRoomSummaryJson({
  String id = '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011',
  String title = 'سهرة طرب',
  String mode = 'SOLO',
  Map<String, Object?>? category,
}) => {
  'id': id,
  'title': title,
  'mode': mode,
  'viewerCount': 0,
  'startedAt': '2026-10-16T19:00:00.000Z',
  'coverUrl': null,
  'category': category,
  'host': {
    'id': '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80',
    'username': 'layla.k',
    'displayName': 'ليلى',
    'avatarUrl': null,
  },
};

/// `listLiveRooms` `onePage` example.
Map<String, Object?> liveRoomPageJson({
  List<Map<String, Object?>>? data,
  String? nextCursor = 'eyJ2IjoxLCJ0IjoibmV3In0.q2Fm0b7xT1sYg8aE3k9Lzw',
  bool hasMore = true,
}) => {
  'data': data ?? [liveRoomSummaryJson()],
  'page': {'nextCursor': nextCursor, 'hasMore': hasMore},
};

/// `getLiveRoom` `ended` example.
Map<String, Object?> endedLiveRoomJson() => {
  ...liveRoomSummaryJson(category: {'slug': 'music', 'name': 'موسيقى'}),
  'status': 'ENDED',
  'endedAt': '2026-10-16T20:12:45.120Z',
  'endReason': 'HOST_ENDED',
};

/// `getPublicProfile` `otherUserLive` example.
Map<String, Object?> publicProfileJson({
  bool isFollowing = true,
  int followerCount = 12,
  bool isSelf = false,
  bool isPrivate = false,
}) => {
  'id': '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80',
  'username': 'layla.k',
  'displayName': 'ليلى',
  'avatarUrl': null,
  'bio': null,
  'isPrivate': isPrivate,
  'followerCount': followerCount,
  'followingCount': 40,
  'isFollowing': isFollowing,
  'isSelf': isSelf,
  'liveRoomId': '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011',
};

/// Categories as the server would return them for [ar]/en.
List<LiveCategory> apiCategories({bool ar = false}) => [
  LiveCategory(slug: 'music', name: ar ? 'موسيقى' : 'Music'),
  LiveCategory(slug: 'chat', name: ar ? 'دردشة' : 'Chat'),
  LiveCategory(slug: 'games', name: ar ? 'ألعاب' : 'Games'),
];

const _hostsEn = ['Sara', 'Omar', 'Layan', 'Yousef', 'Huda', 'Karim'];
const _hostsAr = ['سارة', 'عمر', 'ليان', 'يوسف', 'هدى', 'كريم'];
const _titlesEn = [
  'Arabic music night',
  'Evening chat',
  'Poetry night',
  'Game night',
  'My first live',
  'Questions and answers',
];
const _titlesAr = [
  'أمسية موسيقى عربية',
  'دردشة المساء',
  'أمسية شعر',
  'ألعاب الليلة',
  'أول بث لي',
  'أسئلة وأجوبة',
];

/// [count] v1.3-realistic rooms (viewerCount 0, no cover, no avatar)
/// with ids `room-<start + i>`.
List<LiveRoomSummary> apiRooms(int count, {int start = 0, bool ar = false}) => [
  for (var i = start; i < start + count; i++)
    LiveRoomSummary(
      id: 'room-$i',
      title: (ar ? _titlesAr : _titlesEn)[i % _titlesEn.length],
      mode: LiveRoomMode.solo,
      viewerCount: 0,
      startedAt: DateTime.utc(2026, 10, 16, 19).subtract(Duration(minutes: i)),
      coverUrl: null,
      category: null,
      host: UserSummary(
        id: 'user-$i',
        username: 'host$i',
        displayName: (ar ? _hostsAr : _hostsEn)[i % _hostsEn.length],
        avatarUrl: null,
      ),
    ),
];

/// A page of [rooms] with [nextCursor] (`null` → last page).
LiveRoomPage apiPage(List<LiveRoomSummary> rooms, {String? nextCursor}) =>
    LiveRoomPage(
      data: rooms,
      page: PageInfo(nextCursor: nextCursor, hasMore: nextCursor != null),
    );
