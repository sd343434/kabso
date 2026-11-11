import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/home_banners_provider.dart';
import 'package:kabso_live/features/live/application/live_room_swipe.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/data/live_boost_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/domain/live_boost_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/hub_card_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/hub/live_nearby_country.dart';
import 'package:kabso_live/features/live/presentation/hub/podcast_hub.dart';
import 'package:kabso_live/features/live/presentation/hub/voice_room_list.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/home` — the live-discovery hub, Kabso's home page since D48.
///
/// D131 (owner, ref 165): every live under the filters — D237: Following
/// (first), Nearby (the person's country, D133), Popular ▾ (its menu: All or
/// a category), Featured (hosts featured from admin, D133) and Explore (the
/// newest); every kind together, each card naming its kind (no category
/// row; audio / podcast / multi are also the party page's tabs) — which
/// replaced the
/// Following · Popular · New tabs, the category chips and D129's "voice
/// rooms · live" switch. The voice rooms are the «الحفلة» tab (D322;
/// `VoiceRoomsScreen`, `/live/voice`). D124 stays: the top bar (D322: title,
/// «+», search, bell), the 2-column grid with the promo banners (D248:
/// the carousel after the first row, a card-size banner in one cell), and
/// swiping between this list's lives inside a room. All
/// data comes from the API (`liveRoomsProvider`, `homeBannersProvider`);
/// while the server has hosting switched off the list shows the honest
/// unavailable state with Try again.
///
/// Another screen can ask for a list through `liveHubTabRequestProvider`
/// (following → Following, popular → Popular, new → Explore).
///
/// Freshness (HL-H5): tapping the selected filter (except Popular, which
/// opens its menu) re-fetches it; returning to the app after more than
/// [resumeRefreshAfter] re-fetches the shown list.
class LiveScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const resumeRefreshAfter = Duration(seconds: 60);

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  late LiveHubSelection _selection = _initial();
  late final AppLifecycleListener _lifecycle;
  DateTime? _leftAt;

  LiveHubSelection _initial() {
    final request = ref.read(liveHubTabRequestProvider);
    return request == null
        ? const LiveHubSelection()
        : LiveHubSelection.forTab(request.tab);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _leftAt ??= clock.now(),
      onShow: _returned,
    );
  }

  void _returned() {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null) return;
    if (clock.now().difference(leftAt) > LiveScreen.resumeRefreshAfter) {
      unawaited(
        refreshLoadedLiveTabs(
          ProviderScope.containerOf(context, listen: false),
          [_selection.query],
        ),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _select(LiveHubSelection next) {
    if (next == _selection) {
      unawaited(
        ref
            .read(liveRoomsProvider(next.query).notifier)
            .refresh()
            .catchError((Object _) {}),
      );
      return;
    }
    setState(() => _selection = next);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveHubTabRequestProvider, (_, request) {
      if (request != null) _select(LiveHubSelection.forTab(request.tab));
    });
    final p = context.palette;
    final categories =
        ref.watch(liveDiscoveryCategoriesProvider).value ?? const [];
    return Scaffold(
      backgroundColor: p.background,
      body: KTopSafeArea(
        child: Column(
          children: [
            const LiveHubTopBar(),
            LiveHubFilterBar(
              selection: _selection,
              categories: categories,
              onSelect: _select,
            ),
            // D240: «القريبة»'s country, changeable.
            if (_selection.filter == LiveHubFilter.nearby)
              const LiveNearbyCountryRow(),
            // D237 (owner): no category row — every kind together, each
            // card names its kind; audio, podcast and multi are also the
            // party page's tabs.
            Expanded(
              child: LiveRoomsPage(
                key: ValueKey(_selection),
                query: _selection.query,
                selection: _selection,
                onSelect: _select,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The measured top bar of ref 165 (title cap 30 px ≈ 18 sp black, icons
/// 41 px ≈ 17.5 pt ink). The row keeps Kabso's 48 pt touch targets.
/// D294 (owner: «كلمة كابسو لايف … بخط غامق وأكبر قليلاً»): the title is
/// «كابسو لايف» / "Kabso Live", 3 sp larger (18 → 21).
abstract final class KLiveHubTopBar {
  static const double titleSize = 21;
  static const double iconSize = 22;
}

/// D124: the hub's top bar: the Kabso title at the reading start (D294:
/// right in Arabic, left in English — it follows the app's direction, never
/// forced LTR — in the language's own font, the heaviest bundled face), then
/// toward the end D322's order (owner): «+» (go live — the main way in since
/// the bar's centre button is gone), search (Discover, where the party
/// button was) and the notifications bell at the end. The party page is a
/// bottom tab now (D322: «لا تنسى تشيل زر الحفلة من الشريط العلوي»).
class LiveHubTopBar extends StatelessWidget {
  const new({super.key, this.showNotifications = true});

  /// Off in the gallery (no signed-in user there).
  final bool showNotifications;

  static const titleKey = Key('liveHub.title');
  static const searchKey = Key('liveHub.search');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return SizedBox(
      height: KMetrics.topBarHeight,
      child: Padding(
        // Ref 165: the title 37 px (15.8 pt) from the edge, the bell's ink
        // 36 px (15.3 pt) from the other.
        padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.liveHubBrand,
                key: titleKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.headline.copyWith(
                  color: p.textPrimary,
                  fontSize: KLiveHubTopBar.titleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            // D322: «+» opens go-live (drawn like search).
            const LiveHubGoLiveButton(),
            IconButton(
              key: searchKey,
              tooltip: l10n.feedSearch,
              constraints: const BoxConstraints.tightFor(
                width: KSizes.minTouchTarget,
                height: KSizes.minTouchTarget,
              ),
              onPressed: () => context.push(AppRoutes.discover),
              icon: AppIcon(
                AppIcons.search,
                size: KLiveHubTopBar.iconSize,
                color: p.textPrimary,
              ),
            ),
            if (showNotifications) const NotificationsBell(),
          ],
        ),
      ),
    );
  }
}

/// D322: the hub's «+» — the main way to go live (the bottom bar has no
/// centre button any more). Owner follow-ups: «بدون دائرة وبنفس لون باقي
/// الأزرار» — a plain outline plus drawn like search beside it (same size,
/// stroke, colour and 48 pt target); «لا تظهر قائمة، فقط تدخل إلى صفحة إنشاء
/// اللايف» — a tap opens go-live (`/live/new`) directly, on its default mode;
/// the type is chosen inside go-live as before. Hidden for a Kabso Team
/// account (D283: no live; `/live/new` is staff-blocked).
class LiveHubGoLiveButton extends ConsumerWidget {
  const new({super.key});

  static const buttonKey = Key('liveHub.goLive');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserProvider)?.staff != null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: buttonKey,
      tooltip: context.l10n.liveHubGoLive,
      constraints: const BoxConstraints.tightFor(
        width: KSizes.minTouchTarget,
        height: KSizes.minTouchTarget,
      ),
      onPressed: () => unawaited(context.push(AppRoutes.goLive)),
      icon: AppIcon(
        AppIcons.plusOutline,
        size: KLiveHubTopBar.iconSize,
        color: context.palette.textPrimary,
      ),
    );
  }
}

/// How a room list is laid out: the hub's 2-column grid, or the Voice
/// rooms' list rows (ref 166). D342: the podcast tab's episode cards went
/// with the tab — a podcast is a party card with its badge.
enum LiveRoomsLayout { grid, list }

/// Which empty and unavailable copy a list shows.
enum LiveListKind { following, popular, explore, nearby, featured }

/// One room list from the API ([query]): the content region of the hub and
/// of the Voice rooms screen. Opening a room sets the in-room swipe list
/// (D124); D248: in the hub's grid the promo carousel follows the first row
/// and a card-size banner takes one cell (the Voice rooms' list keeps its
/// banner after the 4th row).
class LiveRoomsPage extends ConsumerWidget {
  const new({
    required this.query,
    super.key,
    this.selection,
    this.onSelect,
    this.listKind,
    this.layout = LiveRoomsLayout.grid,
    this.header,
  });

  final LiveRoomsQuery query;

  /// The hub's selection (its empty states switch filters).
  final LiveHubSelection? selection;
  final ValueChanged<LiveHubSelection>? onSelect;

  /// The copy kind; defaults from [selection] or [query].
  final LiveListKind? listKind;

  final LiveRoomsLayout layout;

  /// A sliver-free header above the rooms (the Voice rooms' "Room" row).
  final Widget? header;

  /// Where a hub banner leads: (D359) an event banner opens that event's
  /// page ([AppRoutes.event]) from its `eventId`, whatever its `link`;
  /// any other banner its allowlisted `link`.
  static HomeBannerTarget? _targetOf(HomeBanner banner) {
    final eventId = banner.eventId;
    if (eventId != null && _uuid.hasMatch(eventId)) {
      return HomeBannerRoute(AppRoutes.event(eventId.toLowerCase()));
    }
    return HomeBannerTarget.parse(banner.link);
  }

  static final _uuid = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void _openBanner(BuildContext context, WidgetRef ref, HomeBanner banner) {
    switch (_targetOf(banner)) {
      case HomeBannerRoute(:final location):
        unawaited(context.push<void>(location));
      case HomeBannerLiveTab(tab: final target):
        openLiveHub(context, ref, target);
      case null:
        break;
    }
  }

  LiveListKind get _kind =>
      listKind ??
      (query.nearby
          ? LiveListKind.nearby
          : query.featured
          ? LiveListKind.featured
          : switch (query.tab) {
              FeedTab.following => LiveListKind.following,
              FeedTab.popular => LiveListKind.popular,
              FeedTab.latest => LiveListKind.explore,
            });

  /// D154b: the lives in a paid «مميز» slot (traffic cards) go first in the
  /// main lists (Popular and Explore, every category, not Following, Nearby
  /// or Featured), those of this list's kind only.
  List<LiveBoostedRoom> _pinned(WidgetRef ref) {
    if (query.nearby ||
        query.featured ||
        query.category != null ||
        query.tab == FeedTab.following) {
      return const [];
    }
    final boosted = ref.watch(liveBoostedRoomsProvider).value ?? const [];
    return [
      for (final b in boosted)
        // D368: a video podcast's slot on the hub, not the party page.
        if (query.kind?.includesRoom(b.room) ?? true) b,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = liveRoomsProvider(query);
    final async = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final hub = async.value;
    final banners = ref.watch(homeBannersProvider).value ?? const [];
    // D248: the card-size banners only in the grid (not the Voice rooms'
    // list, not the podcasts).
    final cards = layout == LiveRoomsLayout.grid
        ? ref.watch(hubCardBannersProvider).value ?? HubCardBanners.empty
        : HubCardBanners.empty;
    final arabic = ref.watch(liveScopeProvider).language == AppLanguage.ar;
    final country = KCountries.byCode(ref.watch(liveCountryProvider));
    final select = onSelect;
    final current = selection;
    return LiveHubBody(
      kind: _kind,
      voice: query.kind == LiveRoomsKind.audio,
      podcast: query.kind == LiveRoomsKind.podcast,
      party: query.kind == LiveRoomsKind.partyAll,
      layout: layout,
      header: header,
      content: liveHubContent(async, pinned: _pinned(ref)),
      countryNotSet: hub?.countryNotSet ?? false,
      countryName: country == null
          ? null
          : KCountries.name(country, arabic: arabic),
      // D240: the viewer's own choice (never the profile).
      onSetCountry: () => unawaited(openLiveNearbyCountryPicker(context, ref)),
      onShowPopular: select == null || current == null
          ? null
          : () => select(const LiveHubSelection()),
      onShowExplore: select == null
          ? null
          : () => select(const LiveHubSelection(filter: LiveHubFilter.explore)),
      onRefresh: () {
        // The banners reload with the list (a failure there shows none).
        // D212: and the announced podcasts (D342: above the party list).
        if (query.kind == LiveRoomsKind.partyAll ||
            query.kind == LiveRoomsKind.podcast) {
          ref.invalidate(scheduledPodcastsProvider);
        }
        ref
          ..invalidate(homeBannersProvider)
          // D248: and the card-size banners.
          ..invalidate(hubCardBannersProvider)
          // D154b: and the featured slots.
          ..invalidate(liveBoostedRoomsProvider);
        return controller.refresh();
      },
      onRetry: controller.retry,
      onLoadMore: () => unawaited(controller.loadMore()),
      onRetryLoadMore: () => unawaited(controller.retryLoadMore()),
      banners: banners,
      cardBanners: cards.banners,
      cardBannerCell: cards.cell,
      onOpenBanner: (banner) => _openBanner(context, ref, banner),
      canOpenBanner: (banner) => _targetOf(banner) != null,
      onOpenRoom: (room) {
        final id = room.roomId;
        if (id == null) return;
        // D124: swiping inside the room moves through this list's rooms.
        ref.read(liveRoomSwipeListProvider.notifier).set([
          for (final r in hub?.rooms ?? const <LiveRoomSummary>[])
            (roomId: r.id, hostId: r.host.id),
        ]);
        unawaited(context.push<void>(AppRoutes.liveRoom(id)));
      },
      refreshWhenUnavailable: true,
    );
  }
}

/// Maps a list's [LiveHubState] to what the region shows.
///
/// A reload ("Try again") of a list that shows nothing yet (unavailable,
/// empty or failed) is loading: its old empty or unavailable state is not
/// shown while the new request runs.
AsyncValue<FeedLoad<LiveRoomCardData>> liveHubContent(
  AsyncValue<LiveHubState> async, {
  List<LiveBoostedRoom> pinned = const [],
}) => switch (async) {
  AsyncValue(:final error?, :final stackTrace, isLoading: false) => AsyncError(
    error,
    stackTrace ?? StackTrace.empty,
  ),
  AsyncValue(
    isLoading: true,
    value: LiveHubState(:final hostingEnabled, :final rooms),
  )
      when !hostingEnabled || rooms.isEmpty =>
    const AsyncLoading(),
  AsyncValue(value: LiveHubState(hostingEnabled: false)) => const AsyncData(
    FeedUnavailable(),
  ),
  AsyncValue(value: final LiveHubState hub) => AsyncData(
    FeedItems(
      [
        // D154b: the «مميز» lives first, then the list without them.
        // D233: each with its rocket stage (badge and animated frame).
        for (final b in pinned)
          LiveRoomCardData.fromSummary(b.room, boostStage: b.stage),
        for (final room in hub.rooms)
          if (!pinned.any((p) => p.room.id == room.id))
            LiveRoomCardData.fromSummary(room),
      ],
      hasMore: hub.hasMore,
      loadingMore: hub.loadingMore,
      loadMoreError: hub.loadMoreError,
    ),
  ),
  _ => const AsyncLoading(),
};

/// One room list (pure; the gallery and goldens render it with samples).
class LiveHubBody extends StatelessWidget {
  const new({
    required this.kind,
    required this.content,
    required this.onRefresh,
    required this.onRetry,
    super.key,
    this.voice = false,
    this.podcast = false,
    this.party = false,
    this.layout = LiveRoomsLayout.grid,
    this.header,
    this.countryNotSet = false,
    this.countryName,
    this.onSetCountry,
    this.onShowPopular,
    this.onShowExplore,
    this.onLoadMore,
    this.onRetryLoadMore,
    this.onOpenRoom,
    this.refreshWhenUnavailable = false,
    this.banners = const [],
    this.cardBanners = const [],
    this.cardBannerCell = HubCardBanners.defaultCell,
    this.onOpenBanner,
    this.canOpenBanner,
  });

  static const setCountryKey = Key('liveHub.setCountry');

  final LiveListKind kind;
  final AsyncValue<FeedLoad<LiveRoomCardData>> content;
  final Future<void> Function() onRefresh;

  /// Re-runs the failed or empty load (config and first page).
  final VoidCallback onRetry;

  /// Voice rooms (their empty copy names voice rooms).
  final bool voice;

  /// D212: the podcast tab (its empty copy names podcasts).
  final bool podcast;

  /// D342: the party page's mixed list (audio, podcast, multi).
  final bool party;
  final LiveRoomsLayout layout;
  final Widget? header;

  /// D133: Nearby answered `COUNTRY_NOT_SET`.
  final bool countryNotSet;

  /// The person's country in the app language (Nearby's empty copy).
  final String? countryName;
  final VoidCallback? onSetCountry;

  /// Empty-state shortcuts to other filters (hub only).
  final VoidCallback? onShowPopular;
  final VoidCallback? onShowExplore;

  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;

  /// Opens a room (`/home/room/:roomId`, KL-034). `null` (gallery,
  /// goldens): cards are not announced or drawn as buttons.
  final ValueChanged<LiveRoomCardData>? onOpenRoom;

  final bool refreshWhenUnavailable;

  /// D124: the active promo banners; D248: after the grid's first row (the
  /// Voice rooms' list: after the 4th row). None: no carousel.
  final List<HomeBanner> banners;

  /// D248: the card-size banners, taking turns in grid cell
  /// [cardBannerCell] (none: no such cell; the grid layout only).
  final List<HomeBanner> cardBanners;
  final int cardBannerCell;
  final ValueChanged<HomeBanner>? onOpenBanner;
  final bool Function(HomeBanner banner)? canOpenBanner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emptyTitle = party
        ? l10n.livePartyEmptyTitle
        : podcast
        ? l10n.livePodcastEmptyTitle
        : voice
        ? l10n.liveVoiceEmptyTitle
        : l10n.liveHubEmptyTitle;
    final emptyBody = party
        ? l10n.livePartyEmptyBody
        : podcast
        ? l10n.livePodcastEmptyBody
        : voice
        ? l10n.liveVoiceEmptyBody
        : l10n.liveHubEmptyBody;
    final (
      String title,
      String body,
      String action,
      VoidCallback? onAction,
      String? secondary,
      VoidCallback? onSecondary,
      IconData icon,
    ) = switch (kind) {
      LiveListKind.following => (
        l10n.liveHubFollowingEmptyTitle,
        l10n.liveHubFollowingEmptyBody,
        onShowPopular == null ? l10n.actionRetry : l10n.feedSeePopular,
        onShowPopular ?? onRetry,
        onShowPopular == null ? null : l10n.actionRetry,
        onShowPopular == null ? null : onRetry,
        Icons.group_outlined,
      ),
      LiveListKind.popular => (
        emptyTitle,
        emptyBody,
        l10n.actionRetry,
        onRetry,
        onShowExplore == null ? null : l10n.liveHubSeeNew,
        onShowExplore,
        Icons.sensors_off_outlined,
      ),
      LiveListKind.explore => (
        emptyTitle,
        emptyBody,
        l10n.actionRetry,
        onRetry,
        null,
        null,
        Icons.sensors_off_outlined,
      ),
      LiveListKind.nearby when countryNotSet => (
        l10n.liveNearbyNoCountryTitle,
        l10n.liveNearbyNoCountryBody,
        l10n.liveNearbySetCountry,
        onSetCountry,
        null,
        null,
        Icons.place_outlined,
      ),
      LiveListKind.nearby => (
        countryName == null
            ? emptyTitle
            : l10n.liveNearbyEmptyTitle(countryName!),
        l10n.liveNearbyEmptyBody,
        l10n.actionRetry,
        onRetry,
        l10n.liveNearbyChangeCountry,
        onSetCountry,
        Icons.place_outlined,
      ),
      LiveListKind.featured => (
        l10n.liveFeaturedEmptyTitle,
        l10n.liveFeaturedEmptyBody,
        l10n.actionRetry,
        onRetry,
        onShowPopular == null ? null : l10n.feedSeePopular,
        onShowPopular,
        Icons.star_outline_rounded,
      ),
    };
    final copy = FeedRegionCopy(
      unavailableIcon: switch (kind) {
        LiveListKind.following => Icons.group_outlined,
        LiveListKind.explore => Icons.new_releases_outlined,
        _ => Icons.sensors_outlined,
      },
      unavailableTitle: switch (kind) {
        LiveListKind.following => l10n.liveHubFollowingUnavailableTitle,
        LiveListKind.explore => l10n.liveHubNewUnavailableTitle,
        _ => l10n.liveHubPopularUnavailableTitle,
      },
      unavailableBody: switch (kind) {
        LiveListKind.following => l10n.liveHubFollowingUnavailableBody,
        LiveListKind.explore => l10n.liveHubNewUnavailableBody,
        _ => l10n.liveHubPopularUnavailableBody,
      },
      // D41: hosting is a server switch; Try again re-checks it.
      unavailableActionLabel: l10n.actionRetry,
      onUnavailableAction: onRetry,
      emptyIcon: icon,
      emptyTitle: title,
      emptyBody: body,
      emptyActionLabel: action,
      onEmptyAction: onAction,
      emptySecondaryActionLabel: secondary,
      onEmptySecondaryAction: onSecondary,
      errorTitle: l10n.liveHubErrorTitle,
      loadMoreFailed: l10n.liveHubLoadMoreFailed,
    );
    final list = layout != LiveRoomsLayout.grid;
    final banner = banners.isEmpty
        ? null
        : KHomeBannerCarousel(
            banners: banners,
            onOpen: onOpenBanner,
            canOpen: canOpenBanner,
            // D248 (ref 375): the hub's indicator bar inside the picture.
            overlayIndicator: !list,
            // D248b: HOME banners are 5:1 (the grid and the Voice rooms).
            aspect: KHomeBannerCarousel.homeAspect,
          );
    final cardBanner = cardBanners.isEmpty || list
        ? null
        : KHubCardBanner(
            banners: cardBanners,
            onOpen: onOpenBanner,
            canOpen: canOpenBanner,
          );
    return FeedRegion<LiveRoomCardData>(
      key: PageStorageKey(
        layout == LiveRoomsLayout.grid
            ? 'live.${kind.name}'
            : 'live.${kind.name}.${layout.name}',
      ),
      content: content,
      copy: copy,
      header: header,
      // D303 (owner): in the grid the promo carousel is the Live home's
      // first block in every state — loading, empty, error — not only above
      // loaded rooms.
      leading: banner == null || list
          ? null
          : SliverPadding(
              key: LiveHubGrid.bannerSlotKey,
              padding: const EdgeInsets.fromLTRB(
                KLiveGrid.inset,
                KLiveGrid.gap,
                KLiveGrid.inset,
                0,
              ),
              sliver: SliverToBoxAdapter(child: banner),
            ),
      onRefresh: onRefresh,
      onRetry: onRetry,
      onLoadMore: onLoadMore,
      onRetryLoadMore: onRetryLoadMore,
      refreshWhenUnavailable: refreshWhenUnavailable,
      loadingSliver: list
          ? VoiceRoomList.skeletonSliver()
          : LiveHubGrid.skeletonSliver(),
      footerLoadingSliver: LiveHubGrid.loadingMoreSliver(context),
      itemsSliver: (rooms) => list
          ? VoiceRoomList.sliver(
              rooms: rooms,
              banner: banner,
              onOpenRoom: onOpenRoom,
            )
          : LiveHubGrid.sliver(
              rooms: rooms,
              cardBanner: cardBanner,
              cardBannerCell: cardBannerCell,
              onOpenRoom: onOpenRoom,
            ),
    );
  }
}
