import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The second row of the Voice rooms header: the person's country
/// (Nearby), Recommendations (every voice room) or one category.
@immutable
class VoiceRoomsScope {
  const new recommended() : nearby = false, category = null;
  const new nearby() : nearby = true, category = null;
  const new category(String this.category) : nearby = false;

  final bool nearby;
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is VoiceRoomsScope &&
      other.nearby == nearby &&
      other.category == category;

  @override
  int get hashCode => Object.hash(nearby, category);
}

/// Measured on ref 166 (393 pt).
abstract final class KVoiceRoomsHeader {
  /// The selected top tab (cap 30 px → 18 sp, heavy) and the others (cap
  /// 25 px → 15 sp), `#262829` / `#85888F` in the light theme.
  static const double tabSelected = 18;
  static const double tab = 15;

  /// The dash under the selected top tab (16 × 6 px = 6.8 × 2.6 pt).
  static const Size dash = Size(6.8, 2.6);

  /// Second-row tabs (cap 22–23 px → 14 sp).
  static const double subTab = 14;

  /// Gaps between top tabs (39–42 px ≈ 17 pt) and second-row tabs
  /// (74–91 px; E ≈ 32 pt).
  static const double tabGap = 17;
  static const double subTabGap = 32;

  /// "Room" (cap 24 px → 15 sp heavy).
  static const double section = 15;

  static const Color lightInk = Color(0xFF262829);
  static const Color lightGrey = Color(0xFF85888F);

  /// The page under the header (sampled `#F4F6FA`).
  static const Color lightPage = Color(0xFFF4F6FA);
}

/// D131: `/live/voice` — the voice rooms and podcasts (`kind=audio`),
/// opened by the Live hub's party button (owner, ref 166).
///
/// - Header: back, Follow · Hot · New (the server tabs following, popular,
///   new; the selected one bold with a dash under it), search and the bell.
/// - Second row: the person's country (D133 `scope=nearby`; "Nearby" while
///   they have none), Recommendations (the default: every voice room) and
///   the server's active categories.
/// - "Rooms" with a list/grid switch: list rows as in ref 166 (default), or
///   the hub's card grid.
/// - The promo banners after the 4th room and swiping between this list's
///   rooms inside a room, like the hub.
class VoiceRoomsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const backKey = Key('voiceRooms.back');
  static const titleKey = Key('voiceRooms.title');
  static const layoutKey = Key('voiceRooms.layout');
  static Key tabKey(FeedTab tab) => Key('voiceRooms.tab.${tab.name}');
  static const nearbyKey = Key('voiceRooms.scope.nearby');
  static const recommendedKey = Key('voiceRooms.scope.recommended');
  static Key categoryKey(String slug) => Key('voiceRooms.scope.$slug');

  @override
  ConsumerState<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends ConsumerState<VoiceRoomsScreen> {
  FeedTab _tab = FeedTab.popular;
  VoiceRoomsScope _scope = const VoiceRoomsScope.recommended();
  LiveRoomsLayout _layout = LiveRoomsLayout.list;
  late final AppLifecycleListener _lifecycle;
  DateTime? _leftAt;

  LiveRoomsQuery get _query => LiveRoomsQuery(
    tab: _tab,
    kind: LiveRoomsKind.audio,
    nearby: _scope.nearby,
    category: _scope.category,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _leftAt ??= clock.now(),
      onShow: () {
        final leftAt = _leftAt;
        _leftAt = null;
        if (leftAt != null &&
            clock.now().difference(leftAt) > LiveScreen.resumeRefreshAfter) {
          unawaited(
            refreshLoadedLiveTabs(
              ProviderScope.containerOf(context, listen: false),
              [_query],
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshShown() => unawaited(
    ref
        .read(liveRoomsProvider(_query).notifier)
        .refresh()
        .catchError((Object _) {}),
  );

  void _selectTab(FeedTab tab) {
    if (tab == _tab) return _refreshShown();
    setState(() => _tab = tab);
  }

  void _selectScope(VoiceRoomsScope scope) {
    if (scope == _scope) return _refreshShown();
    setState(() => _scope = scope);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final categories =
        ref.watch(liveDiscoveryCategoriesProvider).value ?? const [];
    return Scaffold(
      backgroundColor: light ? KVoiceRoomsHeader.lightPage : p.background,
      body: Column(
        children: [
          _Header(
            tab: _tab,
            scope: _scope,
            categories: categories,
            onTab: _selectTab,
            onScope: _selectScope,
          ),
          Expanded(
            child: LiveRoomsPage(
              key: ValueKey((_query, _layout)),
              query: _query,
              layout: _layout,
              header: _SectionRow(
                layout: _layout,
                onToggle: () => setState(
                  () => _layout = _layout == LiveRoomsLayout.list
                      ? LiveRoomsLayout.grid
                      : LiveRoomsLayout.list,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const new({
    required this.tab,
    required this.scope,
    required this.categories,
    required this.onTab,
    required this.onScope,
  });

  final FeedTab tab;
  final VoiceRoomsScope scope;
  final List<LiveCategory> categories;
  final ValueChanged<FeedTab> onTab;
  final ValueChanged<VoiceRoomsScope> onScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final arabic = ref.watch(liveScopeProvider).language == AppLanguage.ar;
    final country = KCountries.byCode(ref.watch(liveCountryProvider));
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale);
    final tabs = {
      FeedTab.following: l10n.liveVoiceTabFollow,
      FeedTab.popular: l10n.liveVoiceTabHot,
      FeedTab.latest: l10n.liveVoiceTabNew,
    };
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: light ? p.surfaceRaised : p.surface,
          boxShadow: light
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: KTopSafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: KMetrics.topBarHeight,
                child: Row(
                  children: [
                    IconButton(
                      key: VoiceRoomsScreen.backKey,
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: KSizes.minTouchTarget,
                      ),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(AppRoutes.home),
                      // Points to the reading start (mirrored in Arabic).
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: p.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        key: VoiceRoomsScreen.titleKey,
                        container: true,
                        explicitChildNodes: true,
                        label: l10n.liveVoiceRoomsTitle,
                        // D139: with the Live button the three tabs can be
                        // wider than their space (Arabic at 360 pt, large
                        // text): they shrink to fit instead of scrolling
                        // the last one out of sight (scale 1 when they fit).
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: KSpacing.xs,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: SizedBox(
                                height: KMetrics.topBarHeight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final (i, t)
                                        in FeedTab.values.indexed) ...[
                                      if (i > 0)
                                        const SizedBox(
                                          width: KVoiceRoomsHeader.tabGap,
                                        ),
                                      _TopTab(
                                        key: VoiceRoomsScreen.tabKey(t),
                                        label: tabs[t]!,
                                        selected: t == tab,
                                        onTap: () => onTab(t),
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
                    IconButton(
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
                    // D139: the owner's Live icon where the hub has the party
                    // button (between search and the bell): back to the
                    // live hub.
                    const VoiceRoomsLiveButton(),
                    const NotificationsBell(),
                    const SizedBox(width: KSpacing.xs),
                  ],
                ),
              ),
              // Ref 166: the second row's centre 34 pt under the first's.
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 21),
                  children: [
                    _SubTab(
                      key: VoiceRoomsScreen.nearbyKey,
                      label: country == null
                          ? l10n.liveHubFilterNearby
                          : KCountries.name(country, arabic: arabic),
                      selected: scope.nearby,
                      onTap: () => onScope(const VoiceRoomsScope.nearby()),
                    ),
                    _SubTab(
                      key: VoiceRoomsScreen.recommendedKey,
                      label: l10n.liveVoiceRecommended,
                      selected: !scope.nearby && scope.category == null,
                      onTap: () => onScope(const VoiceRoomsScope.recommended()),
                    ),
                    for (final c in categories)
                      _SubTab(
                        key: VoiceRoomsScreen.categoryKey(c.slug),
                        label: c.name,
                        selected: scope.category == c.slug,
                        onTap: () => onScope(VoiceRoomsScope.category(c.slug)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.xs),
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
    final ink = light ? KVoiceRoomsHeader.lightInk : p.textPrimary;
    final grey = light ? KVoiceRoomsHeader.lightGrey : p.textTertiary;
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
                fontSize: selected
                    ? KVoiceRoomsHeader.tabSelected
                    : KVoiceRoomsHeader.tab,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: KVoiceRoomsHeader.dash.width,
              height: KVoiceRoomsHeader.dash.height,
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

class _SubTab extends StatelessWidget {
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
    final ink = light ? KVoiceRoomsHeader.lightInk : p.textPrimary;
    final grey = light ? KVoiceRoomsHeader.lightGrey : p.textTertiary;
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
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            end: KVoiceRoomsHeader.subTabGap,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: context.textStyles.body.copyWith(
                color: selected ? ink : grey,
                fontSize: KVoiceRoomsHeader.subTab,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Rooms" and the list/grid switch (ref 166's filter icon is left out:
/// there is no sort or filter sheet behind it).
class _SectionRow extends StatelessWidget {
  const new({required this.layout, required this.onToggle});

  final LiveRoomsLayout layout;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final ink = light ? KVoiceRoomsHeader.lightInk : p.textPrimary;
    final list = layout == LiveRoomsLayout.list;
    // The switch names the layout it turns on.
    final label = list ? l10n.liveVoiceGridView : l10n.liveVoiceListView;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 15.8, end: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.liveVoiceSection,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.title.copyWith(
                  color: ink,
                  fontSize: KVoiceRoomsHeader.section,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          IconButton(
            key: VoiceRoomsScreen.layoutKey,
            tooltip: label,
            constraints: const BoxConstraints.tightFor(
              width: KSizes.minTouchTarget,
              height: KSizes.minTouchTarget,
            ),
            onPressed: onToggle,
            icon: Icon(
              list ? Icons.grid_view_rounded : Icons.view_list_rounded,
              size: 20,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// D139 (owner: «اعمل أيقونة هناك ترجعنا للبث بنفس الطريقة»): the mirror of
/// the hub's party button (D130/D131) in the voice rooms' top bar, in the
/// party button's place (between search and the bell, same 48 pt target,
/// same 24 pt icon). A tap plays the owner's animated Live icon (a screen
/// with a LIVE badge, `KLiveIcon`) with the same light haptic, waits the
/// same lead, then returns to the live hub ([returnToLiveHub]: a pop when
/// the hub is under this page, else a `go`). Screen readers hear "Live".
class VoiceRoomsLiveButton extends StatefulWidget {
  const new({super.key});

  static const buttonKey = Key('voiceRooms.live');

  @override
  State<VoiceRoomsLiveButton> createState() => _VoiceRoomsLiveButtonState();
}

class _VoiceRoomsLiveButtonState extends State<VoiceRoomsLiveButton> {
  final GlobalKey<KLiveIconState> _icon = GlobalKey();
  bool _leaving = false;

  Future<void> _tap() async {
    if (_leaving) return;
    _leaving = true;
    unawaited(HapticFeedback.selectionClick());
    _icon.currentState?.play();
    final lead = KMotion.of(context, LiveHubPartyButton.popLead);
    if (lead > Duration.zero) await Future<void>.delayed(lead);
    _leaving = false;
    if (!mounted) return;
    returnToLiveHub(GoRouter.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.liveVoiceRoomsToLive;
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      button: true,
      label: label,
      onTap: () => unawaited(_tap()),
      excludeSemantics: true,
      child: IconButton(
        key: VoiceRoomsLiveButton.buttonKey,
        tooltip: label,
        // D141 (owner): no grey circle on press — the icon's own animation
        // is the feedback.
        style: noInkIconButtonStyle,
        constraints: const BoxConstraints.tightFor(
          width: KSizes.minTouchTarget,
          height: KSizes.minTouchTarget,
        ),
        onPressed: () => unawaited(_tap()),
        // The screen's inside is the header's own surface.
        icon: KLiveIcon(
          key: _icon,
          surfaceColor: light ? p.surfaceRaised : p.surface,
        ),
      ),
    );
  }
}
