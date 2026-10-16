import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/shell/feed_tabs_scaffold.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/home_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
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
      appBar: AppBar(title: Text(l10n.debugComponentGallery)),
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
              KLiveCoverCard(room: _Samples.rooms.first, showLiveBadge: true),
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

class _RoomDemo extends StatefulWidget {
  const new();

  @override
  State<_RoomDemo> createState() => _RoomDemoState();
}

class _RoomDemoState extends State<_RoomDemo> {
  bool _following = false;

  @override
  Widget build(BuildContext context) => KLiveRoomScaffold(
    header: KHostPill(
      hostName: _Samples.host,
      following: _following,
      onFollow: () => setState(() => _following = !_following),
    ),
    viewers: const KViewerStrip(names: _Samples.viewers, count: 12345),
    onClose: () => Navigator.of(context).maybePop(),
    pk: const KPkScoreBar(
      hostScore: 9000,
      opponentScore: 1000,
      timeLeft: Duration(seconds: 95),
    ),
    chat: const KLiveChatOverlay(lines: _Samples.chat),
    actionBar: KRoomActionBar(
      onGift: () =>
          KGiftPanel.show(context, builder: (_) => const _GiftPanelDemo()),
    ),
  );
}

/// Home feed with sample posts on Popular and New; Following is empty.
class _HomeDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => FeedTabsScaffold(
    pageBuilder: (context, tab, selectTab) => HomeFeedBody(
      tab: tab,
      content: AsyncData(
        FeedItems(tab == FeedTab.following ? const [] : _Samples.posts()),
      ),
      onRefresh: () async {},
      onRetry: () {},
      onSeePopular: () => selectTab(FeedTab.popular),
    ),
  );
}

/// Live hub with sample rooms on Popular and New; Following is empty.
class _LiveHubDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => FeedTabsScaffold(
    pageBuilder: (context, tab, selectTab) => LiveHubBody(
      tab: tab,
      content: AsyncData(
        FeedItems(tab == FeedTab.following ? const [] : _Samples.hubRooms),
      ),
      onRefresh: () async {},
      onRetry: () {},
      onSeePopular: () => selectTab(FeedTab.popular),
    ),
  );
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

  static const counts = [0, 987, 12345, 1234567];
  static const host = 'Sample host';
  static const viewers = ['Viewer A', 'Viewer B', 'Viewer C'];
  static const categories = ['All', 'Music', 'Games', 'Chat', 'PK', 'New'];

  static const rooms = [
    LiveRoomCardData(
      hostName: 'Sample host',
      title: 'Sample title (no cover)',
      viewerCount: 12345,
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

  static final List<LiveRoomCardData> hubRooms = [
    for (var i = 0; i < 4; i++) ...rooms,
  ];

  static List<FeedPostData> posts() {
    final now = DateTime.now();
    return [
      FeedPostData(
        authorName: 'Sample author',
        postedAt: now.subtract(const Duration(minutes: 5)),
        text: 'Sample text post (debug gallery only).',
      ),
      FeedPostData(
        authorName: 'مؤلف تجريبي',
        postedAt: now.subtract(const Duration(hours: 3)),
        text: 'منشور تجريبي للمعرض فقط.',
      ),
      FeedPostData(
        authorName: 'Sample author',
        postedAt: now.subtract(const Duration(days: 2)),
        text: 'Another sample post.',
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
    GiftItemData(id: 'a', name: 'Heart', price: 1, shape: GiftShape.heart),
    GiftItemData(id: 'b', name: 'Star', price: 10, shape: GiftShape.star),
    GiftItemData(id: 'c', name: 'Diamond', price: 99, shape: GiftShape.diamond),
    GiftItemData(id: 'd', name: 'Crown', price: 520, shape: GiftShape.crown),
  ];
}
