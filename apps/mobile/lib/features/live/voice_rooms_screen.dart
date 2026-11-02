import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_nearby_country.dart';
import 'package:kabso_live/features/live/presentation/hub/podcast_hub.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

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

/// D131: `/live/voice` — the party page, opened by the Live hub's party
/// button (owner, ref 166). D237: three kinds, each its own
/// `GET /live/rooms?kind=` list with its real empty / error states.
///
/// D240 (owner: «اقترح بث صوتي بث بودكاست بث متعدد يكون فلتر في الاعلى،
/// وازل البحث والاشعارات من هنا، فقط احفظ زر تبديل بين الحفلة وبث حي على
/// زاوية، باسفل ضع فلاتر نفس فلاتر البث الحي»):
/// - Top row: back (when pushed), the kinds «بث صوتي · بث بودكاست · بث
///   متعدد» as the page's tabs (audio first; the selected one bold with a
///   dash under it, ref 166's tab style), and in the corner only the Live
///   button (party ⇄ live hub; the hub's 🎉 is the other direction). No
///   search, no bell.
/// - Under it the live hub's own filter row (`LiveHubFilterBar`: Following ·
///   Nearby · Popular ▾ · Featured · Explore, the same queries) combined
///   with the selected kind; «القريبة» shows its country row
///   (`LiveNearbyCountryRow`).
/// - "Rooms" with the list/grid switch (audio and multi); the podcast tab
///   keeps its episode cards and announced episodes.
/// - The promo banners after the 4th room and swiping between this list's
///   rooms inside a room, like the hub.
class VoiceRoomsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const backKey = Key('voiceRooms.back');
  static const titleKey = Key('voiceRooms.title');
  static const layoutKey = Key('voiceRooms.layout');

  /// D237: the kind tabs (audio, podcast, multi); D240: the top row.
  static const kindsKey = Key('voiceRooms.kinds');
  static Key kindKey(LiveHubCategory kind) =>
      Key('voiceRooms.kind.${kind.name}');

  @override
  ConsumerState<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends ConsumerState<VoiceRoomsScreen> {
  /// D240: the hub's filters (Popular first, as the hub).
  LiveHubSelection _selection = const LiveHubSelection();

  /// D237: the kind shown (audio rooms first, as before).
  LiveHubCategory _kind = LiveHubCategory.audio;
  LiveRoomsLayout _layout = LiveRoomsLayout.list;
  late final AppLifecycleListener _lifecycle;
  DateTime? _leftAt;

  LiveRoomsQuery get _query => _selection.queryOf(_kind.kind!);

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

  void _selectKind(LiveHubCategory kind) {
    if (kind == _kind) return _refreshShown();
    setState(() => _kind = kind);
  }

  void _select(LiveHubSelection next) {
    if (next == _selection) return _refreshShown();
    setState(() => _selection = next);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final categories =
        ref.watch(liveDiscoveryCategoriesProvider).value ?? const [];
    final surface = light ? p.surfaceRaised : p.surface;
    return Scaffold(
      backgroundColor: light ? KVoiceRoomsHeader.lightPage : p.background,
      body: Column(
        children: [
          _Header(kind: _kind, onKind: _selectKind),
          ColoredBox(
            color: surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // D240: the live hub's filters, with this page's kind.
                LiveHubFilterBar(
                  selection: _selection,
                  categories: categories,
                  onSelect: _select,
                ),
                if (_selection.filter == LiveHubFilter.nearby)
                  const LiveNearbyCountryRow(),
                const SizedBox(height: KSpacing.xs),
              ],
            ),
          ),
          Expanded(
            child: _kind == LiveHubCategory.podcast
                // D212: the podcast's episode cards and announced episodes.
                ? LiveRoomsPage(
                    key: ValueKey(_query),
                    query: _query,
                    selection: _selection,
                    onSelect: _select,
                    layout: LiveRoomsLayout.podcast,
                    header: const ScheduledPodcastsSection(),
                  )
                : LiveRoomsPage(
                    key: ValueKey((_query, _layout)),
                    query: _query,
                    selection: _selection,
                    onSelect: _select,
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

class _Header extends StatelessWidget {
  const new({required this.kind, required this.onKind});

  final LiveHubCategory kind;
  final ValueChanged<LiveHubCategory> onKind;

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
      child: ColoredBox(
        color: light ? p.surfaceRaised : p.surface,
        child: KTopSafeArea(
          child: SizedBox(
            height: KMetrics.topBarHeight,
            child: Row(
              children: [
                if (pushed)
                  IconButton(
                    key: VoiceRoomsScreen.backKey,
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: KSizes.minTouchTarget,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    // Points to the reading start (mirrored in Arabic).
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: p.textPrimary,
                    ),
                  )
                else
                  const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Semantics(
                    key: VoiceRoomsScreen.titleKey,
                    container: true,
                    explicitChildNodes: true,
                    label: l10n.liveVoiceRoomsTitle,
                    // The three kinds shrink to fit (Arabic at 360 pt,
                    // large text) instead of scrolling one out of sight.
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: KSpacing.xs,
                        ),
                        child: FittedBox(
                          key: VoiceRoomsScreen.kindsKey,
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: SizedBox(
                            height: KMetrics.topBarHeight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final (i, k)
                                    in LiveHubCategory.partyPage.indexed) ...[
                                  if (i > 0)
                                    const SizedBox(
                                      width: KVoiceRoomsHeader.tabGap,
                                    ),
                                  _TopTab(
                                    key: VoiceRoomsScreen.kindKey(k),
                                    label: k.label(l10n),
                                    selected: k == kind,
                                    onTap: () => onKind(k),
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
                // D240: only the party ⇄ live switch in the corner.
                const VoiceRoomsLiveButton(),
                const SizedBox(width: KSpacing.xs),
              ],
            ),
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
