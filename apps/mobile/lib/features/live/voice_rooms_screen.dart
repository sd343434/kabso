import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/podcast_hub.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D246: the party page's header and section, measured on the owner's ref
/// (393 lp; the spec stays in scratch). D240's values came from ref 166.
abstract final class KVoiceRoomsHeader {
  /// D377: the top tabs are the shared bar's ([KLiveTopBar]); these names
  /// stay for the party page's measurements.
  static const double tabSelected = KLiveTopBar.tabSelected;
  static const double tab = KLiveTopBar.tab;
  static const double tabInset = KLiveTopBar.tabInset;
  static const double topRow = KLiveTopBar.row;

  /// «القريبة»'s country row under the tabs.
  static const double subRow = KLiveTopBar.subRow;
  static const double subTabInset = KLiveTopBar.subTabInset;

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
/// - One list of every party room — audio and audio podcasts mixed (D368:
///   a live video podcast is the hub's; D369: no multi-guest lives), in the
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
///
/// D377 (owner 2026-11-12: «بجانبي ايقونات الاشعارات والبحث و+ سيكون فلتر
/// الموجود الان في الحفلة — ثم طبق هذا الشريط العلوي على صفحة البث», and
/// «اقترح ازالة ايقونة الاشعارات من الحفلة والبث لانه يكفي في اللحظات»): the
/// top row is the shared [LiveHubTopBar] — these four tabs (same queries,
/// same order) with «+» (go-live on Audio, `/live/new?mode=audio`) and
/// search beside them; the Live hub wears the same bar. No bell (the
/// Moments tab has it). The scheduled podcasts, "Rooms" and everything
/// below are unchanged.
class VoiceRoomsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// D377: the top bar is the shared [LiveHubTopBar]; its keys.
  static const Key backKey = LiveHubTopBar.backKey;
  static const layoutKey = Key('voiceRooms.layout');

  /// D246: the filter tabs (the top row).
  static const Key filtersKey = LiveHubTopBar.tabsKey;
  static Key filterKey(LiveHubFilter filter) => LiveHubTopBar.tabKey(filter);

  /// D246: the party page's filters, in order (D377: the shared bar's).
  static const List<LiveHubFilter> filters = LiveHubTopBar.filters;

  /// D246: Nearby's country, the second row (D342: its only tab).
  static const Key countryKey = LiveHubTopBar.countryKey;

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
          // D377: the shared top bar (the hub wears the same one); «+»
          // opens go-live on Audio.
          LiveHubTopBar(
            filter: _selection.filter,
            onFilter: (f) => _select(LiveHubSelection(filter: f)),
            goLiveMode: LiveRoomMode.audio,
            label: context.l10n.liveVoiceRoomsTitle,
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
