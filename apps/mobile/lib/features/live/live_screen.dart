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
import 'package:kabso_live/features/live/presentation/hub/home_banner_open.dart';
import 'package:kabso_live/features/live/presentation/hub/hub_card_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/hub/live_nearby_country.dart';
import 'package:kabso_live/features/live/presentation/hub/podcast_hub.dart';
import 'package:kabso_live/features/live/presentation/hub/voice_room_list.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/home` — the live-discovery hub, Kabso's home page since D48.
///
/// D377 (owner 2026-11-12): the hub wears the party page's top bar
/// ([LiveHubTopBar], one widget for both pages): no title, the four tabs
/// «المتابَعة · الرائج · استكشاف · القريبة», then «+» and search (no bell:
/// the Moments tab has it). Each tab keeps its hub query over the video
/// lives (`kind=solo`, D239/D368): following, popular (every category: the
/// D131 category menu and the «المميزة» tab are gone from the app; the
/// server keeps both, and the paid «مميز» slots still pin first in Popular
/// and Explore, D154b), explore (the newest) and nearby (D133, its country
/// under the tabs, D240). The voice rooms are the «الحفلة» tab (D322;
/// `VoiceRoomsScreen`, `/live/voice`). D124 stays: the 2-column grid with
/// the promo banners (D248: the carousel after the first row, a card-size
/// banner in one cell), and swiping between this list's lives inside a
/// room. All data comes from the API (`liveRoomsProvider`,
/// `homeBannersProvider`); while the server has hosting switched off the
/// list shows the honest unavailable state with Try again.
///
/// Another screen can ask for a list through `liveHubTabRequestProvider`
/// (following → Following, popular → Popular, new → Explore).
///
/// Freshness (HL-H5): tapping the selected tab re-fetches it; returning to
/// the app after more than [resumeRefreshAfter] re-fetches the shown list.
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
    // D377: the hub has no category menu any more (Popular is «الكل»).
    final plain = LiveHubSelection(filter: next.filter);
    if (plain == _selection) {
      unawaited(
        ref
            .read(liveRoomsProvider(plain.query).notifier)
            .refresh()
            .catchError((Object _) {}),
      );
      return;
    }
    setState(() => _selection = plain);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveHubTabRequestProvider, (_, request) {
      if (request != null) _select(LiveHubSelection.forTab(request.tab));
    });
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          // D377: the party page's bar (no title; its four tabs, then «+»
          // and search) — the same widget on both pages.
          LiveHubTopBar(
            filter: _selection.filter,
            onFilter: (f) => _select(LiveHubSelection(filter: f)),
            label: context.l10n.liveHubBrand,
          ),
          // D237 (owner): no category row — every kind together, each
          // card names its kind; audio and podcast are the party page's
          // (D368: a live video podcast is a hub card, D369: no
          // multi-guest lives).
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
    );
  }
}

/// D377: the shared top bar's geometry — the party page's D246 tabs
/// (measured on the owner's ref, 393 lp) and the hub's D322 icons.
abstract final class KLiveTopBar {
  /// The selected tab (cap 31 px = 13.2 lp → 18 sp, heavy, `#2E3132`) and
  /// the others (cap 24–27 px → 15 sp, `#8D919C`).
  static const double tabSelected = 18;
  static const double tab = 15;

  /// The dash under the selected tab (17 × 7 px = 7.2 × 3 lp).
  static const Size dash = Size(7.2, 3);

  /// The dash's gap under the label line: the ref's dash is 7.3 lp under
  /// the baseline (Latin); Arabic needs more room for its descenders.
  static const double dashGap = 1;
  static const double dashGapArabic = 5;

  /// Gap between tabs (37–40 px = 16.5 lp) and the strip's start inset.
  static const double tabGap = 16.5;
  static const double tabInset = 16.6;

  /// The gap between the last tab and the first icon.
  static const double tabEnd = 8;

  /// The fade at a side of the strip with tabs hidden past it.
  static const double fade = 20;

  /// The row (Kabso's 48 lp top bar) and the icons (ref 165: 41 px ≈
  /// 17.5 pt ink, drawn at 22 lp in 48 lp targets), 4 lp from the end.
  static const double row = KMetrics.topBarHeight;
  static const double iconSize = 22;
  static const double iconsEnd = 4;

  /// «القريبة»'s country row under the tabs (D246; 13 sp, 21.3 lp in).
  static const double subRow = 30;
  static const double subTab = 13;
  static const double subTabInset = 21.3;

  static const Color lightInk = Color(0xFF2E3132);
  static const Color lightGrey = Color(0xFF8D919C);
}

/// D377 (owner 2026-11-12: «بجانبي ايقونات الاشعارات والبحث و+ سيكون فلتر
/// الموجود الان في الحفلة — ثم طبق هذا الشريط العلوي على صفحة البث», then:
/// the live page uses exactly the party page's current tabs): ONE top bar
/// for the Live hub («البث») and the party page («الحفلة»), identical on
/// both: no title, the party page's D246 text tabs «المتابَعة · الرائج ·
/// استكشاف · القريبة» (the selected one heavy with a dash under it) at the
/// reading start, and toward the end D322's «+» (go live) and search
/// (Discover). No bell (owner 2026-11-12: «اقترح ازالة ايقونة الاشعارات من
/// الحفلة والبث لانه يكفي في اللحظات»: the Moments tab keeps it). «القريبة»
/// shows its country under the tabs (D246; a tap opens the D240 picker).
///
/// Each page maps a tab to its own list ([LiveHubSelection]): the hub to
/// its video lives (`kind=solo`), the party page to every party room
/// (`kind=party_all`, D342). The tabs keep their text size: when they do
/// not fit beside the icons (narrow screens, large text) the strip scrolls
/// and the selected tab is scrolled into view.
class LiveHubTopBar extends StatefulWidget {
  const new({
    required this.filter,
    required this.onFilter,
    super.key,
    this.goLiveMode,
    this.label,
  });

  /// The selected tab.
  final LiveHubFilter filter;
  final ValueChanged<LiveHubFilter> onFilter;

  /// The mode «+» opens go-live on (`null`: go-live's default, the hub's;
  /// the party page: audio).
  final LiveRoomMode? goLiveMode;

  /// The screen reader's name of the tabs (the page's name).
  final String? label;

  /// D377: the tabs, in order (the party page's D246 order, both pages).
  static const List<LiveHubFilter> filters = [
    LiveHubFilter.following,
    LiveHubFilter.popular,
    LiveHubFilter.explore,
    LiveHubFilter.nearby,
  ];

  static const tabsKey = Key('liveTop.tabs');
  static Key tabKey(LiveHubFilter filter) => Key('liveTop.tab.${filter.name}');
  static const searchKey = Key('liveHub.search');
  static const backKey = Key('liveTop.back');
  static const countryKey = Key('liveTop.nearbyCountry');

  static String tabLabel(AppLocalizations l10n, LiveHubFilter f) => switch (f) {
    LiveHubFilter.following => l10n.livePartyTabFollowing,
    LiveHubFilter.nearby => l10n.liveHubFilterNearby,
    LiveHubFilter.popular => l10n.liveHubFilterPopular,
    LiveHubFilter.featured => l10n.liveHubFilterFeatured,
    LiveHubFilter.explore => l10n.liveHubFilterExplore,
  };

  @override
  State<LiveHubTopBar> createState() => _LiveHubTopBarState();
}

class _LiveHubTopBarState extends State<LiveHubTopBar> {
  final Map<LiveHubFilter, GlobalKey> _tabs = {
    for (final f in LiveHubTopBar.filters) f: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(LiveHubTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) _reveal(animate: true);
  }

  /// Whether tabs are hidden past the reading start / end of the strip
  /// (it then fades out on that side, a hint that it scrolls).
  bool _moreBefore = false;
  bool _moreAfter = false;

  void _edges(ScrollMetrics m) {
    if (m.axis != Axis.horizontal) return;
    final before = m.extentBefore > 0.5;
    final after = m.extentAfter > 0.5;
    if (before == _moreBefore && after == _moreAfter) return;
    // Notifications come during layout: rebuild after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _moreBefore = before;
        _moreAfter = after;
      });
    });
  }

  /// The strip's edge fade (opaque where tabs show, clear at a hidden
  /// side's last [KLiveTopBar.fade] lp).
  Shader _fade(Rect bounds, TextDirection direction) {
    final w = bounds.width <= 0 ? 1.0 : bounds.width;
    final f = (KLiveTopBar.fade / w).clamp(0.0, 0.5);
    const opaque = Color(0xFFFFFFFF);
    const clear = Color(0x00FFFFFF);
    return LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: [
        if (_moreBefore) clear else opaque,
        opaque,
        opaque,
        if (_moreAfter) clear else opaque,
      ],
      stops: [0, f, 1 - f, 1],
    ).createShader(bounds, textDirection: direction);
  }

  /// Scrolls the selected tab into view, as little as needed (a no-op when
  /// it is already whole on screen, e.g. when the tabs fit).
  void _reveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final duration = animate
          ? KMotion.of(context, KMotion.fast)
          : Duration.zero;
      for (final policy in const [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        final tab = _tabs[widget.filter]?.currentContext;
        if (!mounted || tab == null || !tab.mounted) return;
        await Scrollable.ensureVisible(
          tab,
          duration: duration,
          curve: KMotion.standard,
          alignmentPolicy: policy,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale);
    // D240: the back arrow only when the page was pushed.
    final pushed = Navigator.maybeOf(context)?.canPop() ?? false;
    final filter = widget.filter;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: light ? p.surfaceRaised : p.surface,
          border: light
              ? null
              : Border(bottom: BorderSide(color: p.border, width: 0.5)),
        ),
        child: KTopSafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: KLiveTopBar.row,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: KLiveTopBar.iconsEnd,
                  ),
                  child: Row(
                    children: [
                      if (pushed)
                        IconButton(
                          key: LiveHubTopBar.backKey,
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: KLiveTopBar.row,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).maybePop(),
                          // Points to the reading start (mirrored in Arabic).
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: p.textPrimary,
                          ),
                        ),
                      Expanded(
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          label: widget.label,
                          child:
                              NotificationListener<ScrollMetricsNotification>(
                                onNotification: (n) {
                                  _edges(n.metrics);
                                  return false;
                                },
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (n) {
                                    _edges(n.metrics);
                                    return false;
                                  },
                                  child: ShaderMask(
                                    blendMode: BlendMode.dstIn,
                                    shaderCallback: (bounds) => _fade(
                                      bounds,
                                      Directionality.of(context),
                                    ),
                                    child: SingleChildScrollView(
                                      key: LiveHubTopBar.tabsKey,
                                      scrollDirection: Axis.horizontal,
                                      padding: EdgeInsetsDirectional.only(
                                        start: pushed
                                            ? 0
                                            : KLiveTopBar.tabInset,
                                        end: KLiveTopBar.tabEnd,
                                      ),
                                      child: SizedBox(
                                        height: KLiveTopBar.row,
                                        child: Row(
                                          children: [
                                            for (final (i, f)
                                                in LiveHubTopBar
                                                    .filters
                                                    .indexed) ...[
                                              if (i > 0)
                                                const SizedBox(
                                                  width: KLiveTopBar.tabGap,
                                                ),
                                              KeyedSubtree(
                                                key: _tabs[f],
                                                child: _TopTab(
                                                  key: LiveHubTopBar.tabKey(f),
                                                  label: LiveHubTopBar.tabLabel(
                                                    l10n,
                                                    f,
                                                  ),
                                                  selected: f == filter,
                                                  onTap: () =>
                                                      widget.onFilter(f),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                      // D322: «+» opens go-live (drawn like search).
                      LiveHubGoLiveButton(mode: widget.goLiveMode),
                      IconButton(
                        key: LiveHubTopBar.searchKey,
                        tooltip: l10n.feedSearch,
                        constraints: const BoxConstraints.tightFor(
                          width: KSizes.minTouchTarget,
                          height: KSizes.minTouchTarget,
                        ),
                        onPressed: () => context.push(AppRoutes.discover),
                        icon: AppIcon(
                          AppIcons.search,
                          size: KLiveTopBar.iconSize,
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // D246: «القريبة» keeps its country under the tabs.
              if (filter == LiveHubFilter.nearby)
                const SizedBox(
                  height: KLiveTopBar.subRow,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: KLiveTopBar.subTabInset,
                      end: KLiveTopBar.subTabInset,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _NearbyCountryTab(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final ink = light ? KLiveTopBar.lightInk : p.textPrimary;
    final grey = light ? KLiveTopBar.lightGrey : p.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              style: context.textStyles.title.copyWith(
                color: selected ? ink : grey,
                fontSize: selected ? KLiveTopBar.tabSelected : KLiveTopBar.tab,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                height: 1.2,
              ),
            ),
            // Arabic letters reach under the line (ر, ئ, ج): the dash
            // sits below them instead of touching them.
            SizedBox(
              height: Localizations.localeOf(context).languageCode == 'ar'
                  ? KLiveTopBar.dashGapArabic
                  : KLiveTopBar.dashGap,
            ),
            Container(
              width: KLiveTopBar.dash.width,
              height: KLiveTopBar.dash.height,
              decoration: BoxDecoration(
                color: selected ? ink : const Color(0x00000000),
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D246: «القريبة»'s country under the tabs (the ref's «Jordan»): the
/// flag, the name in the app language and a small ▾; a tap opens the D240
/// picker (kept on this device). No country: «اختر بلداً ▾».
class _NearbyCountryTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final ink = light ? KLiveTopBar.lightInk : p.textPrimary;
    final arabic = ref.watch(liveScopeProvider).language == AppLanguage.ar;
    final country = KCountries.byCode(ref.watch(liveCountryProvider));
    final name = country == null
        ? l10n.liveNearbyChooseCountry
        : KCountries.name(country, arabic: arabic);
    void open() => unawaited(openLiveNearbyCountryPicker(context, ref));
    final style = context.textStyles.label.copyWith(
      color: ink,
      fontSize: KLiveTopBar.subTab,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    return Semantics(
      button: true,
      label: country == null
          ? l10n.liveNearbyChooseCountry
          : l10n.liveNearbyCountryRow(name),
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        key: LiveHubTopBar.countryKey,
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: SizedBox(
          height: KLiveTopBar.subRow,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (country != null) ...[
                // The flag art (`assets/flags/`, as the cards), not the
                // emoji: the same on every phone.
                Image.asset(
                  'assets/flags/${country.code.toLowerCase()}.webp',
                  width: 18,
                  height: 13,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 4),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: p.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D322: the top bar's «+» — the main way to go live (the bottom bar has no
/// centre button any more). Owner follow-ups: «بدون دائرة وبنفس لون باقي
/// الأزرار» — a plain outline plus drawn like search beside it (same size,
/// stroke, colour and 48 pt target); «لا تظهر قائمة، فقط تدخل إلى صفحة إنشاء
/// اللايف» — a tap opens go-live (`/live/new`) directly; the type is chosen
/// inside go-live as before. D377: on the party page it opens go-live on
/// Audio ([mode], `/live/new?mode=audio`). Hidden for a Kabso Team account
/// (D283: no live; `/live/new` is staff-blocked).
class LiveHubGoLiveButton extends ConsumerWidget {
  const new({super.key, this.mode});

  /// The mode go-live opens on (`null`: its default).
  final LiveRoomMode? mode;

  static const buttonKey = Key('liveHub.goLive');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserProvider)?.staff != null) {
      return const SizedBox.shrink();
    }
    final mode = this.mode;
    return IconButton(
      key: buttonKey,
      tooltip: context.l10n.liveHubGoLive,
      constraints: const BoxConstraints.tightFor(
        width: KSizes.minTouchTarget,
        height: KSizes.minTouchTarget,
      ),
      onPressed: () => unawaited(
        context.push(
          mode == null ? AppRoutes.goLive : AppRoutes.goLiveIn(mode.name),
        ),
      ),
      icon: AppIcon(
        AppIcons.plusOutline,
        size: KLiveTopBar.iconSize,
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
        unawaited(openHomeBannerRoute(context, ref, location));
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

  /// D342: the party page's mixed list (audio and audio podcasts).
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
