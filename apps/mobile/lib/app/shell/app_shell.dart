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
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: KBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelect: _onSelect,
        items: [
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
        ],
      ),
    );
  }
}

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

  /// The centered Create action, drawn as a raised gradient button.
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
    final color = selected ? p.primary : p.textSecondary;

    final Widget visual;
    if (item.prominent) {
      visual = AnimatedContainer(
        duration: KMotion.of(context, KMotion.fast),
        curve: KMotion.standard,
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.md),
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: KBrandColors.gradientLive,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: KBrandColors.red500.withValues(alpha: 0.45),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Icon(item.icon, color: p.onPrimary, size: 28),
      );
    } else {
      visual = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(selected ? item.activeIcon : item.icon, color: color, size: 24),
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
      );
    }

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
