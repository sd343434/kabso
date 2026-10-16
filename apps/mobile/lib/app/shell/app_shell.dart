import 'package:go_router/go_router.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Scaffold of the five primary tabs with the custom bottom navigation.
class AppShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onSelect(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab returns to its first page.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: KBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelect: _onSelect,
        items: shellNavItems(context.l10n),
      ),
    );
  }
}

/// The five shell destinations in navigation order (start → end), matching
/// `AppRoutes.shellBranches`.
List<KBottomNavItem> shellNavItems(AppLocalizations l10n) => [
  KBottomNavItem(
    key: const Key('nav.home'),
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: l10n.navHome,
  ),
  KBottomNavItem(
    key: const Key('nav.discover'),
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore_rounded,
    label: l10n.navDiscover,
  ),
  KBottomNavItem(
    key: const Key('nav.create'),
    icon: Icons.add_rounded,
    activeIcon: Icons.add_rounded,
    label: l10n.navCreate,
    prominent: true,
  ),
  KBottomNavItem(
    key: const Key('nav.live'),
    icon: Icons.sensors_outlined,
    activeIcon: Icons.sensors_rounded,
    label: l10n.navLive,
  ),
  KBottomNavItem(
    key: const Key('nav.profile'),
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: l10n.navProfile,
  ),
];

@immutable
class KBottomNavItem {
  const new({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.prominent = false,
  });

  final Key key;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// The centred Create action, drawn as a `primary` pill with no visible
  /// label (the label is its screen-reader name).
  final bool prominent;
}

/// Token-driven bottom navigation. Items are laid out in a [Row], so the
/// order mirrors automatically in RTL (Home at the start edge).
class KBottomNav extends StatelessWidget {
  const new({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  final List<KBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: KSizes.bottomNavHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const new({required this.item, required this.selected, required this.onTap});

  final KBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // HL-N1 §2 styling: the active item is a filled icon, a `textPrimary`
    // label and a 4 dp `primary` dot above the icon; inactive items are
    // outline icons with `textSecondary` labels. Red stays on the dot only.
    final color = selected ? p.textPrimary : p.textSecondary;
    final duration = KMotion.of(context, KMotion.fast);

    final Widget icon;
    if (item.prominent) {
      // G-21 / DESIGN_SYSTEM §9.6: a plain `primary` pill (the live
      // gradient is reserved for live surfaces), 44×32, radius md.
      icon = Container(
        width: KSpacing.xxl + KSpacing.md,
        height: KSpacing.xxl,
        decoration: BoxDecoration(
          color: p.primary,
          borderRadius: BorderRadius.circular(KRadius.md),
        ),
        child: Icon(item.icon, color: p.onPrimary, size: KSpacing.xl),
      );
    } else {
      icon = Icon(
        selected ? item.activeIcon : item.icon,
        color: color,
        size: KMetrics.iconMd,
      );
    }

    final visual = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: duration,
          opacity: selected ? 1 : 0,
          child: Container(
            width: KMetrics.navDotSize,
            height: KMetrics.navDotSize,
            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(height: KSpacing.xxs),
        icon,
        if (!item.prominent) ...[
          const SizedBox(height: KSpacing.xxs),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // The bar has a fixed token height; cap scaling so labels fit.
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: 1.15),
            style: context.textStyles.caption.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      key: item.key,
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KSizes.minTouchTarget,
            minWidth: KSizes.minTouchTarget,
          ),
          child: Center(child: visual),
        ),
      ),
    );
  }
}
