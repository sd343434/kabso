import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D131 (owner, ref 165): the Live hub's filters, replacing the
/// Following · Popular · New tabs and the category chips. D237 (owner):
/// «المتابَعين» is its own tab, the first (it was a choice in Popular's
/// menu): Following · Nearby · Popular ▾ · Featured · Explore. D377
/// (owner 2026-11-12): both the hub and the party page show the party
/// page's four tabs (`LiveHubTopBar.filters`: following, popular,
/// explore, nearby); [featured] stays a query (no tab).
enum LiveHubFilter {
  /// D237: lives of the people the person follows (`tab=following`).
  following,

  /// Lives of hosts from the person's own country (D133 `scope=nearby`).
  nearby,

  /// Popular order; its menu (▾) picks All or a server category.
  popular,

  /// Hosts the team features from admin (D133 `featured=true`).
  featured,

  /// The newest lives (`tab=new`).
  explore,
}

/// D212 (owner: «بث مباشر، بث صوتي، بث بودكاست، بث متعدد، بث ستريمر»):
/// the live categories, each a `kind` of `GET /live/rooms` (server-side);
/// «ستريمر» (phone screen share, D213) has no rooms yet. D237 (owner): the
/// hub no longer has a category row — audio and podcast are the tabs of
/// the party page ([partyPage]), and every hub card names its room's
/// category. D239: and only there (the hub is solo and PK). D369 (owner:
/// «الغي البث المتعدد لا اريده»): the multi-guest category is gone.
enum LiveHubCategory {
  all(null),
  live(LiveRoomsKind.solo),
  audio(LiveRoomsKind.audio),
  podcast(LiveRoomsKind.podcast),
  streamer(null);

  new(this.kind);

  /// The server's filter (`null`: every room, or none for [streamer]).
  final LiveRoomsKind? kind;

  /// D213: the streamer category is not built yet.
  bool get comingSoon => this == streamer;

  /// D237: the party page's tabs, in order.
  static const List<LiveHubCategory> partyPage = [audio, podcast];

  String label(AppLocalizations l10n) => switch (this) {
    all => l10n.liveCategoryAll,
    live => l10n.liveCategoryLive,
    audio => l10n.liveCategoryAudio,
    podcast => l10n.liveCategoryPodcast,
    streamer => l10n.liveCategoryStreamer,
  };
}

/// What the hub shows: a filter, and for Popular its menu choice (All or
/// one server category). D237: no category row; each card names its kind.
/// D239 (owner: «بث صوتي يظهر في غير مكانه»): the main hub lists video
/// lives only — solo and PK (`kind=solo`, server-side, so every filter and
/// its pages agree); audio and podcast are the party page's. D368 (owner:
/// «بودكاست الحي يظهر في صفحة البث وليس الحفلة»): a live VIDEO podcast is a
/// camera live of the hub (`kind=solo` lists it, v1.115-live); an audio
/// podcast stays the party page's.
/// D369: no list has a multi-guest live any more (retired).
@immutable
class LiveHubSelection {
  const new({this.filter = LiveHubFilter.popular, this.category});

  /// The hub as another screen asks for it ("Watch live streams", a
  /// banner's `/live?tab=…`; D237: following → the Following tab).
  factory forTab(FeedTab tab) => switch (tab) {
    FeedTab.following => const LiveHubSelection(
      filter: LiveHubFilter.following,
    ),
    FeedTab.popular => const LiveHubSelection(),
    FeedTab.latest => const LiveHubSelection(filter: LiveHubFilter.explore),
  };

  final LiveHubFilter filter;

  /// Popular's menu: a category slug (`null`: All).
  final String? category;

  /// The room list behind this selection: D239 — video lives only (SOLO,
  /// PK, STREAMER and — D368 — the live video podcasts), under every
  /// filter.
  LiveRoomsQuery get query => _filterQuery.withKind(hubKind);

  /// D240: the same filter's list of one party kind.
  LiveRoomsQuery queryOf(LiveRoomsKind kind) => _filterQuery.withKind(kind);

  /// D342 (owner: «ازل فلاتر بث صوتي بث بوكاست و بث متعدد … ان يكونو بنفس
  /// الصف»): the party page's one list — every party kind (audio and the
  /// audio podcasts; D368: a video podcast is the hub's, D369: no multi)
  /// mixed in this filter's own order, one server list (v1.107-live
  /// `kind=party_all`), never several lists merged here.
  LiveRoomsQuery get partyQuery =>
      _filterQuery.withKind(LiveRoomsKind.partyAll);

  /// D239: the main hub's server `kind` (SOLO, PK, STREAMER; D368: and the
  /// live video podcasts).
  static const LiveRoomsKind hubKind = LiveRoomsKind.solo;

  LiveRoomsQuery get _filterQuery => switch (filter) {
    LiveHubFilter.following => const LiveRoomsQuery(tab: FeedTab.following),
    LiveHubFilter.nearby => const LiveRoomsQuery(
      tab: FeedTab.popular,
      nearby: true,
    ),
    LiveHubFilter.popular => LiveRoomsQuery(
      tab: FeedTab.popular,
      category: category,
    ),
    LiveHubFilter.featured => const LiveRoomsQuery(
      tab: FeedTab.popular,
      featured: true,
    ),
    LiveHubFilter.explore => const LiveRoomsQuery(tab: FeedTab.latest),
  };

  LiveHubSelection withFilter(LiveHubFilter next) =>
      LiveHubSelection(filter: next, category: category);

  @override
  bool operator ==(Object other) =>
      other is LiveHubSelection &&
      other.filter == filter &&
      other.category == category;

  @override
  int get hashCode => Object.hash(filter, category);
}

/// Geometry of the hub's former filter pills, measured on ref 165 (393 pt
/// wide). D377: the hub wears the party page's top bar (`LiveHubTopBar`);
/// the pill row and Popular's category menu are gone from the app (the
/// server keeps `category` and `featured`). [inset] still places the
/// category tabs.
abstract final class KLiveHubFilters {
  /// Pill height (77 px = 32.8 pt).
  static const double height = 33;

  /// Corner radius (≈ 12 px; E).
  static const double radius = 6;

  /// Label padding inside a pill (36–39 px ≈ 16 pt).
  static const double padding = 16;

  /// Gap between pills (17–18 px = 7.5 pt).
  static const double gap = 7.5;

  /// The row's start inset (34 px = 14.5 pt).
  static const double inset = 14.5;

  /// The label (cap 24 px = 10.2 pt → 14 sp).
  static const double fontSize = 14;

  /// Light theme: unselected fill (sampled `#F4F6FA`) and label (`#2E3032`).
  static const Color lightFill = Color(0xFFF4F6FA);
  static const Color lightInk = Color(0xFF2E3032);
}

/// D212: the category tabs' geometry (Kabso's own; no reference).
abstract final class KLiveHubCategories {
  /// The row's height (a 48 pt touch target per tab).
  static const double height = 40;

  /// The label (14 sp; the selected one bold).
  static const double fontSize = 14;

  /// The selected tab's underline.
  static const double underline = 3;
  static const double underlineWidth = 18;

  /// Gap between tabs.
  static const double gap = 16;
}

/// D212 (owner): a row of live-category text tabs on one scrolling line,
/// the selected one bold with a short brand-red underline. D237: no longer
/// on the hub; the party page's three tabs ([LiveHubCategory.partyPage]).
class LiveHubCategoryBar extends StatelessWidget {
  const new({
    required this.selected,
    required this.onSelect,
    super.key,
    this.values = LiveHubCategory.partyPage,
  });

  final LiveHubCategory selected;
  final ValueChanged<LiveHubCategory> onSelect;

  /// The tabs, in order.
  final List<LiveHubCategory> values;

  static Key tabKey(LiveHubCategory c) => Key('liveHub.category.${c.name}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.liveCategoryRowLabel,
        child: SizedBox(
          height: KSizes.minTouchTarget,
          // Every tab is built (a short row; it scrolls on narrow screens).
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: KLiveHubFilters.inset,
            ),
            child: Row(
              children: [
                for (final (i, c) in values.indexed) ...[
                  if (i > 0) const SizedBox(width: KLiveHubCategories.gap),
                  Semantics(
                    button: true,
                    selected: c == selected,
                    inMutuallyExclusiveGroup: true,
                    label: c.comingSoon
                        ? '${c.label(l10n)} · ${l10n.liveSoon}'
                        : c.label(l10n),
                    onTap: () => onSelect(c),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: tabKey(c),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(c),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: KSizes.minTouchTarget,
                          minWidth: 32,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c.label(l10n),
                              maxLines: 1,
                              style: context.textStyles.label.copyWith(
                                fontSize: KLiveHubCategories.fontSize,
                                height: 1.25,
                                color: c == selected
                                    ? p.textPrimary
                                    : p.textSecondary,
                                fontWeight: c == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: KMotion.of(context, KMotion.fast),
                              width: c == selected
                                  ? KLiveHubCategories.underlineWidth
                                  : 0,
                              height: KLiveHubCategories.underline,
                              decoration: BoxDecoration(
                                color: KBrandColors.red500,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
