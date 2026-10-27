import 'dart:async';

import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D131 (owner, ref 165): the Live hub's four filters, replacing the
/// Following · Popular · New tabs and the category chips.
enum LiveHubFilter {
  /// Lives of hosts from the person's own country (D133 `scope=nearby`).
  nearby,

  /// Popular order; its menu (▾) picks Following or a category.
  popular,

  /// Hosts the team features from admin (D133 `featured=true`).
  featured,

  /// The newest lives (`tab=new`).
  explore,
}

/// What the hub shows: a filter, and for Popular its menu choice
/// (Following, All or one category).
@immutable
class LiveHubSelection {
  const new({
    this.filter = LiveHubFilter.popular,
    this.following = false,
    this.category,
  });

  /// The hub as another screen asks for it ("Watch live streams", a
  /// banner's `/live?tab=…`).
  factory forTab(FeedTab tab) => switch (tab) {
    FeedTab.following => const LiveHubSelection(following: true),
    FeedTab.popular => const LiveHubSelection(),
    FeedTab.latest => const LiveHubSelection(filter: LiveHubFilter.explore),
  };

  final LiveHubFilter filter;

  /// Popular's menu: Following (people the person follows).
  final bool following;

  /// Popular's menu: a category slug (`null`: All).
  final String? category;

  /// The room list behind this selection (video lives, D131).
  LiveRoomsQuery get query => switch (filter) {
    LiveHubFilter.nearby => const LiveRoomsQuery(
      tab: FeedTab.popular,
      nearby: true,
    ),
    LiveHubFilter.popular =>
      following
          ? const LiveRoomsQuery(tab: FeedTab.following)
          : LiveRoomsQuery(tab: FeedTab.popular, category: category),
    LiveHubFilter.featured => const LiveRoomsQuery(
      tab: FeedTab.popular,
      featured: true,
    ),
    LiveHubFilter.explore => const LiveRoomsQuery(tab: FeedTab.latest),
  };

  LiveHubSelection withFilter(LiveHubFilter next) =>
      LiveHubSelection(filter: next, following: following, category: category);

  @override
  bool operator ==(Object other) =>
      other is LiveHubSelection &&
      other.filter == filter &&
      other.following == following &&
      other.category == category;

  @override
  int get hashCode => Object.hash(filter, following, category);
}

/// Geometry of the filter row, measured on ref 165 (393 pt wide).
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

/// The hub's filter row (ref 165): Nearby · Popular ▾ · Featured · Explore,
/// rounded-rect pills on one scrolling line. The selected pill is white
/// with a soft shadow and a bold label (dark theme: the raised surface);
/// the others are light grey. Popular shows its menu choice (Following or a
/// category) as its label and its ▾ chevron; tapping it while selected
/// opens the menu.
class LiveHubFilterBar extends StatelessWidget {
  const new({
    required this.selection,
    required this.onSelect,
    super.key,
    this.categories = const [],
  });

  final LiveHubSelection selection;
  final ValueChanged<LiveHubSelection> onSelect;

  /// The server's active categories (Popular's menu).
  final List<LiveCategory> categories;

  static Key pillKey(LiveHubFilter filter) =>
      Key('liveHub.filter.${filter.name}');
  static const menuFollowingKey = Key('liveHub.popularMenu.following');
  static const menuAllKey = Key('liveHub.popularMenu.all');
  static Key menuCategoryKey(String slug) => Key('liveHub.popularMenu.$slug');

  String _popularLabel(AppLocalizations l10n) {
    if (selection.following) return l10n.feedTabFollowing;
    final slug = selection.category;
    if (slug != null) {
      for (final c in categories) {
        if (c.slug == slug) return c.name;
      }
    }
    return l10n.liveHubFilterPopular;
  }

  /// Opens Popular's menu under its pill ([pillContext]).
  Future<void> _openMenu(BuildContext pillContext) async {
    final context = pillContext;
    final l10n = context.l10n;
    final pill = context.findRenderObject();
    if (pill is! RenderBox) return;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final rect = Rect.fromPoints(
      pill.localToGlobal(Offset(0, pill.size.height), ancestor: overlay),
      pill.localToGlobal(pill.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    PopupMenuItem<_MenuChoice> item(
      Key key,
      String label,
      _MenuChoice value, {
      required bool selected,
    }) => PopupMenuItem<_MenuChoice>(
      key: key,
      value: value,
      child: Semantics(
        selected: selected,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 18),
          ],
        ),
      ),
    );
    final choice = await showMenu<_MenuChoice>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        item(
          menuFollowingKey,
          l10n.feedTabFollowing,
          const _MenuChoice.following(),
          selected: selection.following,
        ),
        const PopupMenuDivider(),
        item(
          menuAllKey,
          l10n.liveHubChipAll,
          const _MenuChoice.category(null),
          selected: !selection.following && selection.category == null,
        ),
        for (final c in categories)
          item(
            menuCategoryKey(c.slug),
            c.name,
            _MenuChoice.category(c.slug),
            selected: !selection.following && selection.category == c.slug,
          ),
      ],
    );
    if (choice == null) return;
    onSelect(
      LiveHubSelection(following: choice.following, category: choice.slug),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale);
    final labels = {
      LiveHubFilter.nearby: l10n.liveHubFilterNearby,
      LiveHubFilter.popular: _popularLabel(l10n),
      LiveHubFilter.featured: l10n.liveHubFilterFeatured,
      LiveHubFilter.explore: l10n.liveHubFilterExplore,
    };
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.liveHubFilterLabel,
        child: SizedBox(
          height: KSizes.minTouchTarget,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: KLiveHubFilters.inset,
            ),
            children: [
              for (final (i, filter) in LiveHubFilter.values.indexed) ...[
                if (i > 0) const SizedBox(width: KLiveHubFilters.gap),
                Center(
                  child: _Pill(
                    pillKey: pillKey(filter),
                    label: labels[filter]!,
                    selected: selection.filter == filter,
                    menu: filter == LiveHubFilter.popular,
                    menuHint: filter == LiveHubFilter.popular
                        ? l10n.liveHubPopularMenuHint
                        : null,
                    onTap: (pillContext) {
                      if (filter == LiveHubFilter.popular &&
                          selection.filter == LiveHubFilter.popular) {
                        unawaited(_openMenu(pillContext));
                      } else {
                        // The selected one again: the hub refreshes it.
                        onSelect(selection.withFilter(filter));
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _MenuChoice {
  const new following() : following = true, slug = null;
  const new category(this.slug) : following = false;

  final bool following;
  final String? slug;
}

class _Pill extends StatelessWidget {
  const new({
    required this.pillKey,
    required this.label,
    required this.selected,
    required this.menu,
    required this.onTap,
    this.menuHint,
  });

  final Key pillKey;
  final String label;
  final bool selected;
  final bool menu;
  final String? menuHint;
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) {
    void tap() => onTap(context);
    final p = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final fill = selected
        ? p.surfaceRaised
        : (light ? KLiveHubFilters.lightFill : p.surface);
    final ink = light ? KLiveHubFilters.lightInk : p.textPrimary;
    final style = context.textStyles.label.copyWith(
      fontSize: KLiveHubFilters.fontSize,
      height: 1.2,
      color: selected ? ink : ink.withValues(alpha: light ? 1 : 0.8),
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      hint: selected ? menuHint : null,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        key: pillKey,
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: ConstrainedBox(
          // The 48 pt touch target around the 33 pt pill.
          constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
          child: Center(
            child: AnimatedContainer(
              duration: KMotion.of(context, KMotion.fast),
              curve: KMotion.standard,
              constraints: const BoxConstraints(
                minHeight: KLiveHubFilters.height,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: KLiveHubFilters.padding,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(KLiveHubFilters.radius),
                border: selected && !light ? Border.all(color: p.border) : null,
                boxShadow: selected && light
                    ? const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (menu) ...[
                    const SizedBox(width: KSpacing.xs),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: style.color,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
