import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/debug/live_preview_pk.dart';
import 'package:kabso_live/features/debug/posts_preview_screen.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart'
    show ReportReason;
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';

/// D86: the labelled test data the app shows while "Demo data" is on (test
/// builds only, `kDemoAvailable`). Every name carries "(test)" / "(تجربة)"
/// and every photo is the dev-only preview set. These are the same
/// fixtures the `/debug` previews use, plugged into the real screens'
/// sources.
abstract final class DemoData {
  /// Whether demo names are Arabic (watching the app language).
  static bool arabic(Ref ref) =>
      ref.watch(languageControllerProvider) == AppLanguage.ar;

  /// The demo account (no server, no tokens).
  static User user({required bool ar}) => User(
    id: 'demo-user',
    email: 'demo@example.invalid',
    emailVerified: true,
    username: 'layla.test',
    displayName: ar ? 'ليلى (تجربة)' : 'Layla (test)',
    locale: ar ? 'ar' : 'en',
    role: UserRole.user,
    isPrivate: false,
    createdAt: DateTime.utc(2026),
    bio: ar
        ? 'نبذة تجريبية: موسيقى ورحلات وبث مباشر كل مساء #بيانات_اختبار'
        : 'Test bio: music, trips and a live stream every evening '
              '#test_data',
  );

  static FeedLoad<FeedPostData> posts(HomeFeed feed, {required bool ar}) {
    final all = postsPreviewFixture(ar: ar, now: clock.now());
    return FeedItems(feed == HomeFeed.trending ? all : all.sublist(2));
  }

  static FeedLoad<FeedStoryData> stories({required bool ar}) =>
      FeedItems(storiesPreviewFixture(ar: ar));

  static FeedLoad<FeedReelData> reels(HomeFeed feed, {required bool ar}) {
    final reels = reelsPreviewFixture(
      postsPreviewFixture(ar: ar, now: clock.now()),
    );
    return FeedItems(
      feed == HomeFeed.trending ? reels : reels.reversed.toList(),
    );
  }

  /// A user's posts, reels or saved grid (nine covers).
  static FeedLoad<ProfileGridItem> grid(ProfileGridKey key) => FeedItems([
    for (var i = 0; i < 9; i++)
      ProfileGridItem(
        cover: PreviewPhoto.enabled
            ? PreviewPhotos.image(
                key.tab == ProfileTab.posts
                    ? PreviewPhotoKind.landscape
                    : PreviewPhotoKind.portrait,
                i,
              )
            : null,
        isVideo:
            key.tab == ProfileTab.reels ||
            i % 4 == 1 ||
            (key.tab == ProfileTab.saved && i.isEven),
      ),
  ]);

  /// The id prefix of demo live rooms; their route opens the designed live
  /// room preview in the room's mode.
  static const String roomPrefix = 'demo-';

  /// The preview mode of a demo room id, or `null` for any other id.
  static LivePreviewMode? roomMode(String roomId) {
    if (!roomId.startsWith(roomPrefix)) return null;
    final mode = roomId.substring(roomPrefix.length).split('-').first;
    return LivePreviewMode.values.asNameMap()[mode];
  }
}

/// D86: profiles and follow without a server (demo data).
class DemoProfileRepository implements ProfileRepository {
  const new({required this.ar, required this.self});

  final bool ar;
  final User self;

  @override
  Future<PublicProfile> getProfile(String username) async {
    final isSelf = username == self.username;
    final base = username.split(RegExp('[._]')).last;
    final name = isSelf
        ? self.displayName
        : ar
        ? '$base (تجربة)'
        : '$base (test)';
    return PublicProfile(
      id: 'demo-$username',
      username: username,
      displayName: name,
      avatarUrl: null,
      bio: isSelf ? self.bio : null,
      isPrivate: false,
      followerCount: isSelf ? 5600 : 1280,
      followingCount: isSelf ? 91 : 140,
      isFollowing: false,
      isSelf: isSelf,
      liveRoomId: null,
    );
  }

  @override
  Future<FollowState> follow(String username) async =>
      const FollowState(isFollowing: true, followerCount: 1281);

  @override
  Future<FollowState> unfollow(String username) async =>
      const FollowState(isFollowing: false, followerCount: 1280);
}

/// D86: the live hub without a server (demo data): hosting on, three
/// categories and a handful of rooms in solo, PK 1-v-1 and PK 2-v-2.
class DemoLiveRepository implements LiveRepository {
  const new({required this.ar});

  final bool ar;

  static const _config = LiveConfig(
    hostingEnabled: true,
    heartbeatIntervalSeconds: 30,
    heartbeatStaleAfterSeconds: 90,
  );

  List<LiveCategory> get _categories => [
    LiveCategory(slug: 'chat', name: ar ? 'دردشة' : 'Chat'),
    LiveCategory(slug: 'music', name: ar ? 'موسيقى' : 'Music'),
    LiveCategory(slug: 'games', name: ar ? 'ألعاب' : 'Games'),
  ];

  List<LiveRoomSummary> _rooms() {
    final now = clock.now();
    final names = ar
        ? ['سارة', 'هدى', 'عمر', 'ليلى', 'كريم', 'رانيا', 'سامي', 'نور']
        : ['Sara', 'Huda', 'Omar', 'Layla', 'Karim', 'Rania', 'Sami', 'Nour'];
    final modes = [
      LivePreviewMode.solo,
      LivePreviewMode.pk2,
      LivePreviewMode.solo,
      LivePreviewMode.pk4,
      LivePreviewMode.solo,
      LivePreviewMode.pk2,
      LivePreviewMode.solo,
      LivePreviewMode.solo,
    ];
    return [
      for (var i = 0; i < names.length; i++)
        LiveRoomSummary(
          id: '${DemoData.roomPrefix}${modes[i].name}-$i',
          title: ar ? 'بث تجريبي ${i + 1}' : 'Test live ${i + 1}',
          mode: modes[i] == LivePreviewMode.solo
              ? LiveRoomMode.solo
              : LiveRoomMode.pk,
          viewerCount: const [284, 1930, 76, 5120, 12, 860, 0, 341][i],
          startedAt: now.subtract(Duration(minutes: 7 + i * 11)),
          coverUrl: 'asset:${PreviewPhotos.of(PreviewPhotoKind.portrait, i)}',
          category: _categories[i % _categories.length],
          host: UserSummary(
            id: 'demo-host-$i',
            username: 'test_host_${names[i].toLowerCase()}',
            displayName: ar ? '${names[i]} (تجربة)' : '${names[i]} (test)',
            avatarUrl: null,
          ),
        ),
    ];
  }

  @override
  Future<LiveConfig> getConfig() async => _config;

  @override
  Future<List<LiveCategory>> listCategories() async => _categories;

  @override
  Future<LiveRoomPage> listRooms({
    required LiveRoomsTab tab,
    String? category,
    String? cursor,
    int limit = LiveRepository.defaultPageSize,
  }) async {
    var rooms = _rooms();
    if (category != null) {
      rooms = [
        for (final r in rooms)
          if (r.category?.slug == category) r,
      ];
    }
    rooms = switch (tab) {
      LiveRoomsTab.popular =>
        rooms..sort((a, b) => b.viewerCount.compareTo(a.viewerCount)),
      LiveRoomsTab.latest =>
        rooms..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
      // The demo account follows two hosts.
      LiveRoomsTab.following => rooms.take(2).toList(),
    };
    return LiveRoomPage(
      data: rooms,
      page: const PageInfo(nextCursor: null, hasMore: false),
    );
  }

  @override
  Future<LiveRoom> getRoom(String roomId) async {
    final r = _rooms().firstWhere(
      (r) => r.id == roomId,
      orElse: () => _rooms().first,
    );
    return LiveRoom(
      id: r.id,
      title: r.title,
      mode: r.mode,
      viewerCount: r.viewerCount,
      startedAt: r.startedAt,
      coverUrl: r.coverUrl,
      category: r.category,
      host: r.host,
      status: LiveRoomStatus.live,
      endedAt: null,
      endReason: null,
    );
  }

  // D86: the demo shows the designed live hub only; going live, media and
  // viewers need the real server.
  static const _serverOnly = ServerFailure(
    code: ErrorCode.liveHostingUnavailable,
    rawCode: 'LIVE_HOSTING_UNAVAILABLE',
    debugMessage: 'Demo data: going live needs the server',
    statusCode: 503,
  );

  @override
  Future<LiveRoom> startRoom({
    required String title,
    String? categorySlug,
    bool allowGuests = true,
    LiveRoomMode mode = LiveRoomMode.solo,
    int? seatCount,
    String? theme,
  }) async => throw _serverOnly;

  @override
  Future<LiveRoom> updateRoom(
    String roomId, {
    int? seatCount,
    String? theme,
  }) async => throw _serverOnly;

  @override
  Future<LiveSeats> seats(String roomId) async => throw _serverOnly;

  @override
  Future<LiveSeatRequest> requestSeat(String roomId, {int? seatIndex}) async =>
      throw _serverOnly;

  @override
  Future<void> cancelSeatRequest(String roomId) async => throw _serverOnly;

  @override
  Future<({List<LiveSeatRequest> items, String? next})> seatRequests(
    String roomId, {
    String? cursor,
  }) async => (items: const <LiveSeatRequest>[], next: null);

  @override
  Future<LiveSeats> acceptSeatRequest(
    String roomId,
    String requestId, {
    int? seatIndex,
  }) async => throw _serverOnly;

  @override
  Future<void> declineSeatRequest(String roomId, String requestId) async =>
      throw _serverOnly;

  @override
  Future<LiveSeatInvite> inviteToSeat(
    String roomId,
    String username, {
    int? seatIndex,
  }) async => throw _serverOnly;

  @override
  Future<LiveSeats> acceptSeatInvite(String roomId) async => throw _serverOnly;

  @override
  Future<void> declineSeatInvite(String roomId) async => throw _serverOnly;

  @override
  Future<void> leaveSeat(String roomId) async => throw _serverOnly;

  @override
  Future<LiveSeats> muteSeat(
    String roomId,
    int index, {
    required bool muted,
  }) async => throw _serverOnly;

  @override
  Future<LiveSeats> removeFromSeat(String roomId, int index) async =>
      throw _serverOnly;

  @override
  Future<LiveSeats> lockSeat(
    String roomId,
    int index, {
    required bool locked,
  }) async => throw _serverOnly;

  @override
  Future<LiveSeats> addModerator(String roomId, String username) async =>
      throw _serverOnly;

  @override
  Future<LiveSeats> removeModerator(String roomId, String username) async =>
      throw _serverOnly;

  @override
  Future<void> heartbeat(String roomId) async => throw _serverOnly;

  @override
  Future<LiveRoom> endRoom(String roomId) async => throw _serverOnly;

  @override
  Future<LiveRoom> setAllowGuests(String roomId, {required bool allow}) async =>
      throw _serverOnly;

  @override
  Future<LiveMediaAccess> mediaToken(String roomId, {String? guestId}) async =>
      throw _serverOnly;

  @override
  Future<({List<LiveViewer> items, String? next})> viewers(
    String roomId, {
    String? cursor,
  }) async => (items: const <LiveViewer>[], next: null);

  @override
  Future<LiveTapsResult> tap(String roomId, int count) async =>
      throw _serverOnly;

  @override
  Future<LiveRoom> editRoom(
    String roomId, {
    required String title,
    required String? categorySlug,
    required String? topic,
  }) async => throw _serverOnly;

  // The demo hub has no taps, so nobody contributed.
  @override
  Future<List<LiveContributor>> contributors(String roomId) async => const [];

  // CP-013: the demo hub has no server, so no chat.
  @override
  Future<List<LiveChatEntry>> chatMessages(String roomId) async => const [];

  @override
  Future<LiveChatEntry> sendChat(
    String roomId, {
    required String text,
    required String clientId,
  }) async => throw _serverOnly;

  @override
  Future<void> deleteChat(String roomId, String messageId) async =>
      throw _serverOnly;

  @override
  Future<List<LiveChatMute>> chatMutes(String roomId) async => const [];

  @override
  Future<void> setChatMuted(
    String roomId,
    String username, {
    required bool muted,
  }) async => throw _serverOnly;

  @override
  Future<LiveRoom> setChatEnabled(
    String roomId, {
    required bool enabled,
  }) async => throw _serverOnly;

  @override
  Future<void> reportChatMessage(String messageId, ReportReason reason) async =>
      throw _serverOnly;

  // CP-017: no server, so no clips, pictures, bullets or coins.
  @override
  Future<LiveChatEntry> sendChatMedia(
    String roomId, {
    required LiveChatKind kind,
    required String mediaId,
    required String clientId,
  }) async => throw _serverOnly;

  @override
  Future<({LiveBullet bullet, int coins})> sendBullet(
    String roomId, {
    required String text,
    required String clientId,
  }) async => throw _serverOnly;

  @override
  Future<int> myCoins() async => 0;
}
