import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
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
///   and a search button (24 dp icon, 48 dp target) at the end that opens
///   Discover;
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
  });

  static const searchKey = Key('feed.search');
  static const pagerKey = Key('feed.pager');

  final FeedTabPageBuilder pageBuilder;
  final FeedTab initialTab;

  /// Defaults to `context.go(AppRoutes.discover)`.
  final VoidCallback? onSearch;

  /// Tapping the tab that is already selected (e.g. the Live hub re-fetches,
  /// HL-H5).
  final ValueChanged<FeedTab>? onReselect;

  @override
  State<FeedTabsScaffold> createState() => _FeedTabsScaffoldState();
}

class _FeedTabsScaffoldState extends State<FeedTabsScaffold> {
  late FeedTab _tab = widget.initialTab;
  late final PageController _pages = PageController(
    initialPage: widget.initialTab.index,
  );

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
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: KMetrics.topBarHeight,
              child: Row(
                children: [
                  Expanded(
                    child: KPrimaryTabs(
                      labels: [for (final tab in FeedTab.values) labels[tab]!],
                      selectedIndex: _tab.index,
                      onSelected: (i) => _select(FeedTab.values[i]),
                    ),
                  ),
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
                        widget.onSearch ?? () => context.go(AppRoutes.discover),
                    icon: const Icon(Icons.search_rounded),
                  ),
                  const SizedBox(width: KSpacing.xs),
                ],
              ),
            ),
            Expanded(
              child: PageView(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
