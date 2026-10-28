import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/guest_seats.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_layout.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_score_bar.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/debug/components` — KL-022 component gallery. **Debug and profile
/// builds only**: the route is registered behind `!kReleaseMode` (so this
/// screen is tree-shaken out of release builds) and the samples below are
/// clearly fake. Never reuse them in production screens (Home and Live keep
/// their empty states until the Phase 6/7 APIs exist).
///
/// Section names are developer-facing and intentionally not localized.
class ComponentGalleryScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  int _tab = 0;
  int _primaryTab = 1;
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    assert(!kReleaseMode, 'The component gallery must not ship in release.');
    final l10n = context.l10n;
    return Scaffold(
      appBar: KAppBar(title: Text(l10n.debugComponentGallery)),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          const _Section(_Samples.badgesTitle),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              const KBadge.live(),
              const KBadge.pk(),
              const KBadge.newRoom(),
              const KBadge.multiGuest(count: 4),
              for (final n in _Samples.counts) KViewerCountChip(count: n),
            ],
          ),
          const _Section(_Samples.avatarsTitle),
          Wrap(
            spacing: KSpacing.lg,
            runSpacing: KSpacing.lg,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final ring in KAvatarRing.values)
                KAvatar(name: _Samples.host, ring: ring),
              for (final ring in KAvatarRing.values.skip(1))
                KAvatar.story(name: _Samples.viewers[1], ring: ring),
            ],
          ),
          const _Section(_Samples.primaryTabsTitle),
          KPrimaryTabs(
            labels: _Samples.primaryTabs,
            selectedIndex: _primaryTab,
            onSelected: (i) => setState(() => _primaryTab = i),
          ),
          KChipRow(
            children: [
              for (var i = 0; i < _Samples.categories.length; i++)
                KChip(
                  label: _Samples.categories[i],
                  selected: i == _chip,
                  onSelected: () => setState(() => _chip = i),
                ),
            ],
          ),
          const _Section(_Samples.tabsTitle),
          KScrollableTabs(
            labels: _Samples.categories,
            selectedIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
          const _Section(_Samples.cardsTitle),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: KMetrics.liveGridGap,
            crossAxisSpacing: KMetrics.liveGridGap,
            childAspectRatio: KSizes.liveCardAspect,
            children: [
              for (final room in _Samples.rooms) KLiveCoverCard(room: room),
              // Opt-out of the LIVE badge (KL-047: on by default).
              KLiveCoverCard(room: _Samples.rooms.first, showLiveBadge: false),
              const KLiveCoverCardSkeleton(),
            ],
          ),
          const _Section(_Samples.statesTitle),
          const KEmptyState(
            compact: true,
            icon: Icons.sensors_outlined,
            title: 'Compact empty state',
            message: 'In-place state under tabs and chips (VG-03).',
          ),
          KErrorState(
            compact: true,
            title: 'Compact error state',
            message: 'Retry re-runs the request.',
            retryLabel: l10n.actionRetry,
            onRetry: () {},
          ),
          const _Section(_Samples.pkTitle),
          const KPkScoreBar(
            hostScore: 9000,
            opponentScore: 1000,
            timeLeft: Duration(seconds: 95),
          ),
          const SizedBox(height: KSpacing.md),
          const KPkScoreBar(
            hostScore: 4200,
            opponentScore: 3800,
            result: PkResult.win,
          ),
          const _Section(_Samples.chatTitle),
          const SizedBox(
            height: KSizes.avatarLg * 3,
            child: KLiveSurface(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KLiveVideoPlaceholder(),
                  KLiveChatOverlay(lines: _Samples.chat),
                ],
              ),
            ),
          ),
          const _Section(_Samples.sheetsTitle),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              KButton(
                label: l10n.liveGifts,
                expand: false,
                icon: Icons.card_giftcard,
                onPressed: () => KGiftPanel.show(
                  context,
                  builder: (_) => const _GiftPanelDemo(),
                ),
              ),
              KButton(
                label: l10n.navLive,
                expand: false,
                variant: KButtonVariant.secondary,
                icon: Icons.live_tv_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const _RoomDemo()),
                ),
              ),
            ],
          ),
          const _Section(_Samples.roomStatesTitle),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final variant in _RoomVariant.values.skip(1))
                KButton(
                  key: Key('gallery.room.${variant.name}'),
                  label: variant.label,
                  expand: false,
                  variant: KButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _RoomDemo(variant: variant),
                    ),
                  ),
                ),
            ],
          ),
          const _Section(_Samples.screensTitle),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              KButton(
                key: const Key('gallery.homeFeed'),
                label: _Samples.homeDemo,
                expand: false,
                variant: KButtonVariant.secondary,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const _HomeDemo()),
                ),
              ),
              KButton(
                key: const Key('gallery.liveHub'),
                label: _Samples.liveHubDemo,
                expand: false,
                variant: KButtonVariant.secondary,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const _LiveHubDemo()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      top: KSpacing.xl,
      bottom: KSpacing.sm,
    ),
    child: Text(name, style: context.textStyles.title),
  );
}

class _GiftPanelDemo extends StatefulWidget {
  const new();

  @override
  State<_GiftPanelDemo> createState() => _GiftPanelDemoState();
}

class _GiftPanelDemoState extends State<_GiftPanelDemo> {
  String? _selected;
  int _combo = 0;

  @override
  Widget build(BuildContext context) => KGiftPanel(
    gifts: _Samples.gifts,
    selectedId: _selected,
    comboCount: _combo,
    onSelected: (gift) => setState(() {
      _combo = gift.id == _selected ? _combo + 1 : 1;
      _selected = gift.id;
    }),
  );
}

/// Room layouts and states with obvious samples (debug only). Production
/// shows only the video-unavailable, ended, not-found and error states.
enum _RoomVariant {
  populated('Populated room'),
  pk('PK split'),
  multiGuest('Multi-guest seats'),
  weak('Weak connection'),
  reconnecting('Reconnecting'),
  cameraOff('Camera off'),
  videoUnavailable('Video unavailable'),
  ended('Ended');

  new(this.label);

  final String label;
}

class _RoomDemo extends StatefulWidget {
  const new({this.variant = _RoomVariant.populated});

  final _RoomVariant variant;

  @override
  State<_RoomDemo> createState() => _RoomDemoState();
}

class _RoomDemoState extends State<_RoomDemo> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final variant = widget.variant;
    const frame = _SampleVideo();
    final ended = variant == _RoomVariant.ended;
    void close() => Navigator.of(context).maybePop();
    return KLiveRoomScaffold(
      video: switch (variant) {
        _RoomVariant.reconnecting => const KRoomReconnecting(frame: frame),
        _RoomVariant.cameraOff => const KRoomCameraOff(hostName: _Samples.host),
        _RoomVariant.videoUnavailable ||
        _RoomVariant.ended => const KRoomVideoUnavailable(),
        _ => frame,
      },
      header: KHostPill(
        hostName: _Samples.host,
        subtitle: _Samples.followers,
        following: _following,
        onFollow: () => setState(() => _following = !_following),
        onTap: () {},
      ),
      viewers: const KViewerStrip(names: _Samples.viewers, count: 12345),
      onClose: close,
      roomInfo: const KRoomInfoRow(
        title: _Samples.roomTitle,
        category: _Samples.roomCategory,
      ),
      statusChip: variant == _RoomVariant.weak
          ? KRoomStatusChip(label: l10n.liveRoomWeakConnection)
          : null,
      stage: switch (variant) {
        _RoomVariant.pk => const KPkLayout(
          host: PkSideData(
            name: _Samples.host,
            score: 9000,
            video: frame,
            supporters: _Samples.viewers,
          ),
          opponent: PkSideData(
            name: _Samples.opponent,
            score: 1000,
            supporters: _Samples.viewers,
          ),
          timeLeft: Duration(seconds: 95),
        ),
        _RoomVariant.multiGuest => const KGuestSeatGrid(
          seats: [
            GuestSeatData(name: _Samples.host, isHost: true, video: frame),
            GuestSeatData(name: 'Viewer A'),
            GuestSeatData(name: 'Viewer B', muted: true),
            GuestSeatData(name: 'Viewer C'),
            null,
            null,
          ],
        ),
        _ => null,
      },
      chat: ended ? null : const KLiveChatOverlay(lines: _Samples.chat),
      actionBar: ended
          ? null
          : KRoomActionBar(
              onComment: () {},
              onShare: () {},
              onGift: () => KGiftPanel.show(
                context,
                builder: (_) => const _GiftPanelDemo(),
              ),
            ),
      cover: ended
          ? KRoomEndedOverlay(
              hostName: _Samples.host,
              reason: l10n.liveRoomEndedByHost,
              onBack: close,
            )
          : null,
    );
  }
}

/// A token-coloured stand-in for a video frame (debug only).
class _SampleVideo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KLiveColors.pkRight, KBrandColors.red700],
      ),
    ),
  );
}

/// The Reels tab (Posts · Reels, Trending · Following) with sample posts
/// and reels. The demo
/// overrides Home's data sources, which return "unavailable" in production.
class _HomeDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final posts = _Samples.posts();
    final reels = [
      for (final post in posts)
        FeedReelData(
          authorName: post.authorName,
          postedAt: post.postedAt,
          caption: post.text,
          cover: post.media,
        ),
    ];
    return ProviderScope(
      overrides: [
        homePostsProvider.overrideWith((ref, _) => FeedItems(posts)),
        homeReelsProvider.overrideWith((ref, _) => FeedItems(reels)),
      ],
      child: const FeedScreen(showNotifications: false),
    );
  }
}

/// Live hub with sample rooms and sample categories on Popular and New;
/// Following is empty.
class _LiveHubDemo extends StatefulWidget {
  const new();

  @override
  State<_LiveHubDemo> createState() => _LiveHubDemoState();
}

class _LiveHubDemoState extends State<_LiveHubDemo> {
  LiveHubSelection _selection = const LiveHubSelection();

  @override
  Widget build(BuildContext context) {
    // D131: the hub's filters over the video samples (Following empty).
    final following =
        _selection.filter == LiveHubFilter.popular && _selection.following;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LiveHubTopBar(showNotifications: false),
            LiveHubFilterBar(
              selection: _selection,
              categories: _Samples.liveCategories,
              onSelect: (next) => setState(() => _selection = next),
            ),
            Expanded(
              child: LiveHubBody(
                kind: following ? LiveListKind.following : LiveListKind.popular,
                content: AsyncData(
                  FeedItems(
                    following
                        ? const []
                        : [
                            for (final room in _Samples.hubRooms)
                              if (!room.isAudio) room,
                          ],
                  ),
                ),
                onRefresh: () async {},
                onRetry: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Obviously fake gallery samples (debug only).
abstract final class _Samples {
  static const badgesTitle = 'Badges · viewer count';
  static const avatarsTitle = 'Avatar rings';
  static const primaryTabsTitle = 'Primary tabs · chips';
  static const statesTitle = 'Compact states';
  static const screensTitle = 'Home feed · Live hub (samples)';
  static const homeDemo = 'Home feed demo';
  static const liveHubDemo = 'Live hub demo';
  static const primaryTabs = ['Following', 'Popular', 'New'];
  static const tabsTitle = 'Scrollable tabs';
  static const cardsTitle = 'Live cover cards';
  static const pkTitle = 'PK score bar';
  static const chatTitle = 'Chat overlay';
  static const sheetsTitle = 'Gift panel · room scaffold';
  static const roomStatesTitle = 'Room layouts and states (samples)';
  static const followers = '1,234 followers (sample)';
  static const roomTitle = 'Sample room title';
  static const roomCategory = 'Sample category';
  static const opponent = 'Sample opponent';

  static const counts = [0, 987, 12345, 1234567];
  static const host = 'Sample host';
  static const viewers = ['Viewer A', 'Viewer B', 'Viewer C'];
  static const categories = ['All', 'Music', 'Games', 'Chat', 'PK', 'New'];
  static const liveCategories = [
    LiveCategory(slug: 'sample-a', name: 'Sample A'),
    LiveCategory(slug: 'sample-b', name: 'Sample B'),
    LiveCategory(slug: 'sample-c', name: 'Sample C'),
  ];

  static const rooms = [
    LiveRoomCardData(
      hostName: 'Sample host',
      title: 'Sample title (no cover)',
      viewerCount: 12345,
      categoryName: 'Sample category',
    ),
    LiveRoomCardData(
      hostName: 'مضيف تجريبي',
      title: 'عنوان تجريبي',
      viewerCount: 987,
      inPk: true,
    ),
    LiveRoomCardData(
      hostName: 'Sample guest room',
      title: 'Multi-guest sample',
      viewerCount: 42,
      guestCount: 4,
    ),
    LiveRoomCardData(
      hostName: 'Sample new host',
      title: 'Just started (0 viewers)',
      viewerCount: 0,
    ),
  ];

  /// The Home live hub demo: the samples with preview photos (KL-056).
  static final List<LiveRoomCardData> hubRooms = [
    for (var i = 0; i < 16; i++)
      LiveRoomCardData(
        hostName: rooms[i % rooms.length].hostName,
        title: rooms[i % rooms.length].title,
        viewerCount: rooms[i % rooms.length].viewerCount,
        inPk: rooms[i % rooms.length].inPk,
        guestCount: rooms[i % rooms.length].guestCount,
        categoryName: rooms[i % rooms.length].categoryName,
        cover: PreviewPhotos.cover(i),
        hostAvatar: PreviewPhotos.avatar(i),
        // D129: every other sample is a voice room (not in PK).
        isAudio: i.isOdd && !rooms[i % rooms.length].inPk,
      ),
  ];

  static List<FeedPostData> posts() {
    final now = DateTime.now();
    return [
      FeedPostData(
        authorName: 'Sample author',
        authorAvatar: PreviewPhotos.avatar(0),
        postedAt: now.subtract(const Duration(minutes: 5)),
        text: 'Sample text post (debug gallery only).',
        media: PreviewPhoto.enabled
            ? PreviewPhotos.image(PreviewPhotoKind.landscape, 1)
            : null,
        mediaAspect: 1200 / 896,
      ),
      FeedPostData(
        authorName: 'مؤلف تجريبي',
        postedAt: now.subtract(const Duration(hours: 3)),
        text: 'منشور تجريبي للمعرض فقط.',
      ),
      FeedPostData(
        authorName: 'Sample author',
        authorAvatar: PreviewPhotos.avatar(2),
        postedAt: now.subtract(const Duration(days: 2)),
        text: 'Another sample post.',
        media: PreviewPhoto.enabled
            ? PreviewPhotos.image(PreviewPhotoKind.landscape, 2)
            : null,
        mediaAspect: 1,
      ),
    ];
  }

  static const chat = <LiveChatLine>[
    LiveChatSystem(text: 'System notice sample'),
    LiveChatJoin(name: 'viewer_a'),
    LiveChatMessage(name: 'Viewer A', text: 'Sample message'),
    LiveChatMessage(name: 'مشاهد', text: 'رسالة تجريبية'),
    LiveChatGift(name: 'Viewer B', giftName: 'Star', count: 3),
  ];

  static const gifts = [
    GiftItemData(id: 'a', name: 'Heart', shape: GiftShape.heart),
    GiftItemData(id: 'b', name: 'Star', shape: GiftShape.star),
    GiftItemData(id: 'c', name: 'Diamond', shape: GiftShape.diamond),
    GiftItemData(id: 'd', name: 'Crown', shape: GiftShape.crown),
  ];
}
