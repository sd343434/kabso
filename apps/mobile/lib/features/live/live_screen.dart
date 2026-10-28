import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
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
import 'package:kabso_live/features/auth/presentation/country_picker.dart';
import 'package:kabso_live/features/live/application/home_banners_provider.dart';
import 'package:kabso_live/features/live/application/live_room_swipe.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/data/live_boost_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/hub/voice_room_list.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/home` — the live-discovery hub, Kabso's home page since D48.
///
/// D131 (owner, ref 165): every live video (`kind=video`: solo, PK and
/// multi-guest) under four filters — Nearby (the person's country, D133),
/// Popular ▾ (its menu: Following, All or a category), Featured (hosts
/// featured from admin, D133) and Explore (the newest) — which replaced the
/// Following · Popular · New tabs, the category chips and D129's "voice
/// rooms · live" switch. The voice rooms open from the party button
/// (`VoiceRoomsScreen`, `/live/voice`). D124 stays: the top bar (title,
/// search, party, bell), the 2-column grid with the promo banners after
/// the 4th card, and swiping between this list's lives inside a room. All
/// data comes from the API (`liveRoomsProvider`, `homeBannersProvider`);
/// while the server has hosting switched off the list shows the honest
/// unavailable state with Try again.
///
/// Another screen can ask for a list through `liveHubTabRequestProvider`
/// (following → Popular ▾ Following, popular → Popular, new → Explore).
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
abstract final class KLiveHubTopBar {
  static const double titleSize = 18;
  static const double iconSize = 22;
}

/// D124: the hub's top bar: the Kabso title at the reading start, search
/// (Discover), the party button (D130, D131: opens the voice rooms) and the
/// notifications bell at the end.
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
            // D130/D131: the owner's party button opens the voice rooms.
            const LiveHubPartyButton(),
            if (showNotifications) const NotificationsBell(),
          ],
        ),
      ),
    );
  }
}

/// D130: the owner's party popper in the hub's top bar, beside the bell.
/// D131 (owner): it opens the voice rooms (`VoiceRoomsScreen`): a tap plays
/// the pop, then pushes `/live/voice`. Screen readers hear "Voice rooms".
class LiveHubPartyButton extends StatefulWidget {
  const new({super.key});

  static const buttonKey = Key('liveHub.party');

  /// How long the pop plays before the voice rooms open.
  static const popLead = Duration(milliseconds: 280);

  @override
  State<LiveHubPartyButton> createState() => _LiveHubPartyButtonState();
}

class _LiveHubPartyButtonState extends State<LiveHubPartyButton> {
  final GlobalKey<KPartyIconState> _icon = GlobalKey();
  bool _opening = false;

  Future<void> _tap() async {
    if (_opening) return;
    _opening = true;
    unawaited(HapticFeedback.selectionClick());
    _icon.currentState?.play();
    final lead = KMotion.of(context, LiveHubPartyButton.popLead);
    if (lead > Duration.zero) await Future<void>.delayed(lead);
    _opening = false;
    if (!mounted) return;
    unawaited(context.push<void>(AppRoutes.voiceRooms));
  }

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.liveVoiceRoomsTitle;
    return Semantics(
      button: true,
      label: label,
      onTap: () => unawaited(_tap()),
      excludeSemantics: true,
      child: IconButton(
        key: LiveHubPartyButton.buttonKey,
        tooltip: label,
        // D141 (owner): no grey circle on press — the icon's own animation
        // is the feedback.
        style: noInkIconButtonStyle,
        constraints: const BoxConstraints.tightFor(
          width: KSizes.minTouchTarget,
          height: KSizes.minTouchTarget,
        ),
        onPressed: () => unawaited(_tap()),
        icon: KPartyIcon(key: _icon),
      ),
    );
  }
}

/// How a room list is laid out: the hub's 2-column grid, or the Voice
/// rooms' list rows (ref 166).
enum LiveRoomsLayout { grid, list }

/// Which empty and unavailable copy a list shows.
enum LiveListKind { following, popular, explore, nearby, featured }

/// One room list from the API ([query]): the content region of the hub and
/// of the Voice rooms screen. Opening a room sets the in-room swipe list
/// (D124); a promo banner follows the 4th room.
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

  void _openBanner(BuildContext context, WidgetRef ref, HomeBanner banner) {
    switch (HomeBannerTarget.parse(banner.link)) {
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
  List<LiveRoomSummary> _pinned(WidgetRef ref) {
    if (query.nearby ||
        query.featured ||
        query.category != null ||
        query.tab == FeedTab.following) {
      return const [];
    }
    final boosted = ref.watch(liveBoostedRoomsProvider).value ?? const [];
    return [
      for (final b in boosted)
        if (query.kind.includes(b.room.mode)) b.room,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = liveRoomsProvider(query);
    final async = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final hub = async.value;
    final banners = ref.watch(homeBannersProvider).value ?? const [];
    final arabic = ref.watch(liveScopeProvider).language == AppLanguage.ar;
    final country = KCountries.byCode(ref.watch(liveCountryProvider));
    final select = onSelect;
    final current = selection;
    return LiveHubBody(
      kind: _kind,
      voice: query.kind == LiveRoomsKind.audio,
      layout: layout,
      header: header,
      content: liveHubContent(async, pinned: _pinned(ref)),
      countryNotSet: hub?.countryNotSet ?? false,
      countryName: country == null
          ? null
          : KCountries.name(country, arabic: arabic),
      onSetCountry: () => unawaited(showCountryPicker(context)),
      onShowPopular: select == null || current == null
          ? null
          : () => select(const LiveHubSelection()),
      onShowExplore: select == null
          ? null
          : () => select(const LiveHubSelection(filter: LiveHubFilter.explore)),
      onRefresh: () {
        // The banners reload with the list (a failure there shows none).
        ref
          ..invalidate(homeBannersProvider)
          // D154b: and the featured slots.
          ..invalidate(liveBoostedRoomsProvider);
        return controller.refresh();
      },
      onRetry: controller.retry,
      onLoadMore: () => unawaited(controller.loadMore()),
      onRetryLoadMore: () => unawaited(controller.retryLoadMore()),
      banners: banners,
      onOpenBanner: (banner) => _openBanner(context, ref, banner),
      canOpenBanner: (banner) => HomeBannerTarget.parse(banner.link) != null,
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
  List<LiveRoomSummary> pinned = const [],
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
        for (final room in pinned)
          LiveRoomCardData.fromSummary(room, featured: true),
        for (final room in hub.rooms)
          if (!pinned.any((p) => p.id == room.id))
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

  /// D124: the active promo banners, shown after the 4th room (none: no
  /// carousel).
  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onOpenBanner;
  final bool Function(HomeBanner banner)? canOpenBanner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emptyTitle = voice
        ? l10n.liveVoiceEmptyTitle
        : l10n.liveHubEmptyTitle;
    final emptyBody = voice ? l10n.liveVoiceEmptyBody : l10n.liveHubEmptyBody;
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
    final banner = banners.isEmpty
        ? null
        : KHomeBannerCarousel(
            banners: banners,
            onOpen: onOpenBanner,
            canOpen: canOpenBanner,
          );
    final list = layout == LiveRoomsLayout.list;
    return FeedRegion<LiveRoomCardData>(
      key: PageStorageKey(
        layout == LiveRoomsLayout.grid
            ? 'live.${kind.name}'
            : 'live.${kind.name}.list',
      ),
      content: content,
      copy: copy,
      header: header,
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
              banner: banner,
              onOpenRoom: onOpenRoom,
            ),
    );
  }
}

/// D141: an icon button with no ink — no highlight, splash or hover circle
/// (the hub's party button and the voice rooms' Live button animate their
/// own icon instead).
const noInkIconButtonStyle = ButtonStyle(
  overlayColor: WidgetStatePropertyAll(Color(0x00000000)),
  splashFactory: NoSplash.splashFactory,
);
