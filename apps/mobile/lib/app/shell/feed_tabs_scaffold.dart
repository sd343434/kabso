import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Builds one tab page. [selectTab] switches the header to another tab (e.g.
/// "See popular" on an empty Following tab).
typedef FeedTabPageBuilder = Widget Function(
  BuildContext context,
  FeedTab tab,
  ValueChanged<FeedTab> selectTab,
);

/// Shell-tab layout shared by the Home feed and the Live hub (HL-H1/H2,
/// VG-05/22/42):
///
/// - a 48 dp header on `background` (no title, wordmark, divider or
///   decorative icons): [KPrimaryTabs] Following · Popular · New at the start
///   and, only while [searchAvailable], a search button (24 dp icon, 48 dp
///   target) at the end that opens Discover;
/// - one page per tab below it, swiped horizontally in the reading direction
///   (RTL: the next tab is to the left). Tapping a tab moves the pager
///   (instantly with reduce motion).
class FeedTabsScaffold extends StatefulWidget {
  const new({
    required this.pageBuilder,
    super.key,
    this.initialTab = FeedTab.initial,
    this.onSearch,
    this.onReselect,
    this.showSearch = searchAvailable,
    this.requestedTab,
    this.overlayHeader = false,
    this.centerTabs = false,
    this.topBar,
  });

  static const searchKey = Key('feed.search');
  static const pagerKey = Key('feed.pager');

  /// KL-047: there is no search capability yet (no search API; `/discover`
  /// is a placeholder), so the header shows no search control: an inert
  /// control must not pass for a finished feature. This is the one switch
  /// to flip when search exists.
  static const bool searchAvailable = false;

  final FeedTabPageBuilder pageBuilder;
  final FeedTab initialTab;

  /// Whether the header shows the search button (defaults to
  /// [searchAvailable]).
  final bool showSearch;

  /// Shows the requested tab: as the first tab when the scaffold is first
  /// built, and by switching to it whenever a newer request arrives (e.g.
  /// Home's "Watch live streams" opening the Live hub on Following).
  final FeedTabRequest? requestedTab;

  /// Defaults to `context.push(AppRoutes.discover)`.
  final VoidCallback? onSearch;

  /// Tapping the tab that is already selected (e.g. the Live hub re-fetches,
  /// HL-H5).
  final ValueChanged<FeedTab>? onReselect;

  /// D50: pages are full-bleed (under the status bar too) and the header
  /// floats over them on a top scrim with light status-bar icons (the
  /// full-screen live hub). Pages place their own content below
  /// [overlayHeaderExtent].
  final bool overlayHeader;

  /// D51: the tabs are centred with space between them (live hub).
  final bool centerTabs;

  /// D124: a bar above the tabs (the live hub's title, search and bell);
  /// not with [overlayHeader].
  final Widget? topBar;

  /// The height the floating header covers: the top safe area plus the
  /// 48 dp tab bar.
  static double overlayHeaderExtent(BuildContext context) =>
      KTopInset.of(context) + KMetrics.topBarHeight;

  @override
  State<FeedTabsScaffold> createState() => _FeedTabsScaffoldState();
}

class _FeedTabsScaffoldState extends State<FeedTabsScaffold> {
  late FeedTab _tab = widget.requestedTab?.tab ?? widget.initialTab;
  late final PageController _pages = PageController(initialPage: _tab.index);

  @override
  void didUpdateWidget(FeedTabsScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.requestedTab;
    if (request != null && request != oldWidget.requestedTab) {
      // A request is not a re-select: never re-fetch the current tab.
      if (request.tab != _tab) _select(request.tab);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(FeedTab tab) {
    if (tab == _tab) {
      widget.onReselect?.call(tab);
      return;
    }
    setState(() => _tab = tab);
    final duration = KMotion.of(context, KMotion.base);
    if (duration == Duration.zero) {
      _pages.jumpToPage(tab.index);
    } else {
      _pages.animateToPage(
        tab.index,
        duration: duration,
        curve: KMotion.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final labels = {
      FeedTab.following: l10n.feedTabFollowing,
      FeedTab.popular: l10n.feedTabPopular,
      FeedTab.latest: l10n.feedTabNew,
    };
    final header = SizedBox(
      height: KMetrics.topBarHeight,
      child: Row(
        children: [
          Expanded(
            child: KPrimaryTabs(
              centered: widget.centerTabs,
              labels: [for (final tab in FeedTab.values) labels[tab]!],
              selectedIndex: _tab.index,
              onSelected: (i) => _select(FeedTab.values[i]),
            ),
          ),
          if (widget.showSearch) ...[
            IconButton(
              key: FeedTabsScaffold.searchKey,
              tooltip: l10n.feedSearch,
              iconSize: KMetrics.iconMd,
              color: p.textPrimary,
              constraints: const BoxConstraints.tightFor(
                width: KSizes.minTouchTarget,
                height: KSizes.minTouchTarget,
              ),
              onPressed:
                  widget.onSearch ?? () => context.push(AppRoutes.discover),
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: KSpacing.xs),
          ],
        ],
      ),
    );
    final pages = PageView(
      key: FeedTabsScaffold.pagerKey,
      controller: _pages,
      onPageChanged: (i) {
        final tab = FeedTab.values[i];
        if (tab != _tab) setState(() => _tab = tab);
      },
      children: [
        for (final tab in FeedTab.values)
          widget.pageBuilder(context, tab, _select),
      ],
    );
    if (widget.overlayHeader) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: p.background,
          body: Stack(
            children: [
              Positioned.fill(child: pages),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x80000000), Color(0x00000000)],
                    ),
                  ),
                  child: KTopSafeArea(child: header),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: p.background,
      body: KTopSafeArea(
        child: Column(
          children: [
            ?widget.topBar,
            header,
            Expanded(child: pages),
          ],
        ),
      ),
    );
  }
}
