import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_nearby_country.dart';
import 'package:kabso_live/features/live/presentation/hub/podcast_hub.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D246: the party page's header and section, measured on the owner's ref
/// (393 lp; the spec stays in scratch). D240's values came from ref 166.
abstract final class KVoiceRoomsHeader {
  /// Top row (the filters): the selected tab (cap 31 px = 13.2 lp → 18 sp,
  /// heavy, `#2E3132`) and the others (cap 24–27 px → 15 sp, `#8D919C`).
  static const double tabSelected = 18;
  static const double tab = 15;

  /// The dash under the selected top tab (17 × 7 px = 7.2 × 3 lp).
  static const Size dash = Size(7.2, 3);

  /// The dash's gap under the label line: the ref's dash is 7.3 lp under
  /// the baseline (Latin); Arabic needs more room for its descenders.
  static const double dashGap = 1;
  static const double dashGapArabic = 5;

  /// Second row (D342: only Nearby's country; the kinds are gone): cap
  /// 22 px = 9.4 lp → 13 sp.
  static const double subTab = 13;

  /// Gap between top tabs (37–40 px = 16.5 lp).
  static const double tabGap = 16.5;

  /// Start insets: top row 16.6 lp, second row 21.3 lp.
  static const double tabInset = 16.6;
  static const double subTabInset = 21.3;

  /// The rows' heights. The ref's rows are ≈ 30 and 25 lp; ours keep the
  /// 48 lp top bar (as every top bar) and, with «القريبة» only (D342), a
  /// 30 lp second row under D142's 10 lp status-bar gap.
  static const double topRow = KMetrics.topBarHeight;
  static const double subRow = 30;

  /// "Rooms" (cap 25 px = 10.6 lp → 15 sp heavy), 15.75 lp in.
  static const double section = 15;
  static const double sectionInset = 15.75;

  /// The section row (centred 29 lp under the header; the first card 48 lp
  /// under it).
  static const double sectionRow = 40;
  static const double sectionTop = 8;

  static const Color lightInk = Color(0xFF2E3132);
  static const Color lightGrey = Color(0xFF8D919C);

  /// The page under the header (sampled `#F4F6FA`); white right under the
  /// header for 25 lp, faded into the page by 81 lp (sampled).
  static const Color lightPage = Color(0xFFF4F6FA);
  static const double fadeWhite = 25;
  static const double fadeEnd = 81;

  /// The soft edge under the header (292–307 px ≈ 6 lp, `#F1F1F1` first).
  static const double edge = 6;
}

/// D131: `/live/voice` — the party page, opened by the Live hub's party
/// button (owner, ref 166); D322: the «الحفلة» tab. D237: three kinds, each
/// its own `GET /live/rooms?kind=` list — until D342.
///
/// D342 (owner 2026-11-09: «ازل فلاتر بث صوتي بث بوكاست و بث متعدد … ان
/// يكونو بنفس الصف لكن ميز كل واحده بهم» and «زر في الاعلى لنقل المستخدم
/// على لايف … ازله»):
/// - No kinds row and no Live switch in the corner (the bar's «البث» tab
///   is the way to the hub).
/// - One list of every party room — audio, podcast and multi mixed, in the
///   selected filter's own order: one server list (`kind=party_all`,
///   v1.107-live) paged by one cursor, never three lists merged here; each
///   card says its kind on its picture (D362: `LiveTypeTag`, a tiny tag
///   beside the live wave, no glyph). The announced podcasts (D212) stay above
///   "Rooms" when there are any.
///
/// D246 (owner, a reference: «اجعله بتصميم مطابق من حيث الأيقونات والحجم،
/// واجعل تصنيفات بث صوتي بودكاست متعدد في الأسفل وبخط أصغر، ومحلهم متابعة
/// ونار واستكشف وقريبة، وامسح المتبقي من الأسفل»):
/// - Top row: back (when pushed), the filters as big tabs «المتابَعة ·
///   الرائج · استكشاف · القريبة» (the hub's own queries: following,
///   popular, explore, nearby; Popular first selected), the selected one
///   heavy with a dash under it. D342: nothing in the corner.
/// - Second row, smaller, with «القريبة» only (D342): the viewer's country
///   «🇯🇴 الأردن ▾» (the ref's «Jordan» slot): a tap opens the D240 picker
///   (a choice on this device; the profile country first).
/// - Removed: D240's pill row, its separate country row and Popular's
///   category menu. «المميزة» has no tab: the paid «مميز» lives already
///   pin first in «الرائج» and «استكشاف», and their cards say «مميز».
/// - "Rooms" with the list/grid switch; no filter icon (nothing behind it).
/// - The promo banners after the 4th room and swiping between this list's
///   rooms inside a room, like the hub.
class VoiceRoomsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const backKey = Key('voiceRooms.back');
  static const titleKey = Key('voiceRooms.title');
  static const layoutKey = Key('voiceRooms.layout');

  /// D246: the filter tabs (the top row).
  static const filtersKey = Key('voiceRooms.filters');
  static Key filterKey(LiveHubFilter filter) =>
      Key('voiceRooms.filter.${filter.name}');

  /// D246: the party page's filters, in order.
  static const List<LiveHubFilter> filters = [
    LiveHubFilter.following,
    LiveHubFilter.popular,
    LiveHubFilter.explore,
    LiveHubFilter.nearby,
  ];

  /// D246: Nearby's country, the second row (D342: its only tab).
  static const countryKey = Key('voiceRooms.nearbyCountry');

  @override
  ConsumerState<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends ConsumerState<VoiceRoomsScreen> {
  /// D246: the selected filter (Popular first, as the hub; never a
  /// category: the party page has no category menu).
  LiveHubSelection _selection = const LiveHubSelection();
  LiveRoomsLayout _layout = LiveRoomsLayout.list;
  late final AppLifecycleListener _lifecycle;
  DateTime? _leftAt;

  /// D342: every party kind in one list, in the filter's own order.
  LiveRoomsQuery get _query => _selection.partyQuery;

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

  void _select(LiveHubSelection next) {
    // The party page has no category menu (an empty state's «الرائج»).
    final plain = LiveHubSelection(filter: next.filter);
    if (plain == _selection) return _refreshShown();
    setState(() => _selection = plain);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final page = LiveRoomsPage(
      key: ValueKey((_query, _layout)),
      query: _query,
      selection: _selection,
      onSelect: _select,
      layout: _layout,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // D212: the announced episodes (nothing when none); D342: above
          // the mixed list, as they were above the podcast tab's.
          const ScheduledPodcastsSection(),
          _SectionRow(
            layout: _layout,
            onToggle: () => setState(
              () => _layout = _layout == LiveRoomsLayout.list
                  ? LiveRoomsLayout.grid
                  : LiveRoomsLayout.list,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: light ? KVoiceRoomsHeader.lightPage : p.background,
      body: Column(
        children: [
          _Header(
            filter: _selection.filter,
            onFilter: (f) => _select(LiveHubSelection(filter: f)),
          ),
          Expanded(
            child: light
                ? Stack(
                    children: [
                      // The ref's white under the header, fading into the
                      // page (behind the "Rooms" row).
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: KVoiceRoomsHeader.fadeEnd,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [
                                0,
                                KVoiceRoomsHeader.fadeWhite /
                                    KVoiceRoomsHeader.fadeEnd,
                                1,
                              ],
                              colors: [
                                Color(0xFFFFFFFF),
                                Color(0xFFFFFFFF),
                                KVoiceRoomsHeader.lightPage,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(child: page),
                      // The ref's soft edge under the header (#F1F1F1 fading
                      // out over ≈ 6 lp), over the list as it scrolls under.
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: KVoiceRoomsHeader.edge,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x10000000), Color(0x00000000)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : page,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.filter, required this.onFilter});

  final LiveHubFilter filter;
  final ValueChanged<LiveHubFilter> onFilter;

  static String filterLabel(AppLocalizations l10n, LiveHubFilter f) =>
      switch (f) {
        LiveHubFilter.following => l10n.livePartyTabFollowing,
        LiveHubFilter.nearby => l10n.liveHubFilterNearby,
        LiveHubFilter.popular => l10n.liveHubFilterPopular,
        LiveHubFilter.featured => l10n.liveHubFilterFeatured,
        LiveHubFilter.explore => l10n.liveHubFilterExplore,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale);
    // D240: the back arrow only when this page was pushed.
    final pushed = Navigator.maybeOf(context)?.canPop() ?? false;
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
                height: KVoiceRoomsHeader.topRow,
                child: Row(
                  children: [
                    if (pushed)
                      IconButton(
                        key: VoiceRoomsScreen.backKey,
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: KVoiceRoomsHeader.topRow,
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
                        key: VoiceRoomsScreen.titleKey,
                        container: true,
                        explicitChildNodes: true,
                        label: l10n.liveVoiceRoomsTitle,
                        // The four tabs shrink to fit (Arabic at 360 lp,
                        // large text) instead of scrolling one out of sight.
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: pushed ? 0 : KVoiceRoomsHeader.tabInset,
                            end: KVoiceRoomsHeader.tabInset,
                          ),
                          child: FittedBox(
                            key: VoiceRoomsScreen.filtersKey,
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: SizedBox(
                              height: KVoiceRoomsHeader.topRow,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final (i, f)
                                      in VoiceRoomsScreen.filters.indexed) ...[
                                    if (i > 0)
                                      const SizedBox(
                                        width: KVoiceRoomsHeader.tabGap,
                                      ),
                                    _TopTab(
                                      key: VoiceRoomsScreen.filterKey(f),
                                      label: filterLabel(l10n, f),
                                      selected: f == filter,
                                      onTap: () => onFilter(f),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // D342 (owner: «زر في الاعلى لنقل المستخدم على لايف …
                    // ازله»): no Live switch in the corner any more.
                  ],
                ),
              ),
              // D342: the kinds row is gone; «القريبة» keeps its country.
              if (filter == LiveHubFilter.nearby)
                const SizedBox(
                  height: KVoiceRoomsHeader.subRow,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: KVoiceRoomsHeader.subTabInset,
                      end: KVoiceRoomsHeader.subTabInset,
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
            // Arabic letters reach under the line (ر, ئ, ج): the dash
            // sits below them instead of touching them.
            SizedBox(
              height: Localizations.localeOf(context).languageCode == 'ar'
                  ? KVoiceRoomsHeader.dashGapArabic
                  : KVoiceRoomsHeader.dashGap,
            ),
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

/// D246: «القريبة»'s country at the start of the second row (the ref's
/// «Jordan»): the flag, the name in the app language and a small ▾; a tap
/// opens the D240 picker (kept on this device). No country: «اختر بلداً ▾».
class _NearbyCountryTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final ink = light ? KVoiceRoomsHeader.lightInk : p.textPrimary;
    final arabic = ref.watch(liveScopeProvider).language == AppLanguage.ar;
    final country = KCountries.byCode(ref.watch(liveCountryProvider));
    final name = country == null
        ? l10n.liveNearbyChooseCountry
        : KCountries.name(country, arabic: arabic);
    void open() => unawaited(openLiveNearbyCountryPicker(context, ref));
    final style = context.textStyles.label.copyWith(
      color: ink,
      fontSize: KVoiceRoomsHeader.subTab,
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
        key: VoiceRoomsScreen.countryKey,
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: SizedBox(
          height: KVoiceRoomsHeader.subRow,
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

/// "Rooms" and the list/grid switch. The ref's filter icon is left out:
/// there is no sort or filter sheet behind it (no fake controls).
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
      padding: const EdgeInsetsDirectional.only(
        start: KVoiceRoomsHeader.sectionInset,
        top: KVoiceRoomsHeader.sectionTop,
      ),
      child: SizedBox(
        height: KVoiceRoomsHeader.sectionRow,
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
                height: KVoiceRoomsHeader.sectionRow,
              ),
              padding: EdgeInsets.zero,
              onPressed: onToggle,
              icon: Icon(
                list ? Icons.grid_view_rounded : Icons.view_list_rounded,
                size: 20,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
