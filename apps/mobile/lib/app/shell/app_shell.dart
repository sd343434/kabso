import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
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
    // Create is a full-screen flow (owner's reference, KL-060): it has its
    // own Close and Back, so the bar is hidden there.
    final creating =
        navigationShell.currentIndex ==
        AppRoutes.shellBranches.indexOf(AppRoutes.create);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: creating
          ? null
          : KBottomNav(
              currentIndex: navigationShell.currentIndex,
              onSelect: _onSelect,
              items: shellNavItems(context.l10n),
            ),
    );
  }
}

/// The five shell destinations in navigation order (start → end), matching
/// `AppRoutes.shellBranches` (D86: Live · Posts · Create · Messages · Me).
/// Icons: the owner's Kabso set (D56).
List<KBottomNavItem> shellNavItems(AppLocalizations l10n) => [
  KBottomNavItem(
    key: const Key('nav.home'),
    icon: KNavIcons.liveOutline,
    activeIcon: KNavIcons.liveFilled,
    label: l10n.navLive,
  ),
  KBottomNavItem(
    key: const Key('nav.reels'),
    icon: KNavIcons.homeOutline,
    activeIcon: KNavIcons.homeFilled,
    label: l10n.navPosts,
  ),
  KBottomNavItem(
    key: const Key('nav.create'),
    icon: KNavIcons.create,
    activeIcon: KNavIcons.create,
    label: l10n.navCreate,
    prominent: true,
  ),
  KBottomNavItem(
    key: const Key('nav.messages'),
    icon: KNavIcons.inboxOutline,
    activeIcon: KNavIcons.inboxFilled,
    label: l10n.navMessages,
  ),
  KBottomNavItem(
    key: const Key('nav.profile'),
    icon: KNavIcons.profileOutline,
    activeIcon: KNavIcons.profileFilled,
    label: l10n.navProfile,
  ),
];

/// The bottom-bar icons (D56): the owner's Kabso set, outline when
/// inactive and filled when active, drawn in `currentColor`. The Create
/// pill keeps its red asset (D49).
abstract final class KNavIcons {
  static const String _p = 'assets/icons';
  static const String homeOutline = '$_p/home_outline.svg';
  static const String homeFilled = '$_p/home_filled.svg';
  static const String discoverOutline = '$_p/discover_outline.svg';
  static const String discoverFilled = '$_p/discover_filled.svg';
  static const String reelsOutline = '$_p/reels_outline.svg';
  static const String reelsFilled = '$_p/reels_filled.svg';
  static const String profileOutline = '$_p/profile_outline.svg';
  static const String profileFilled = '$_p/profile_filled.svg';
  static const String liveOutline = '$_p/live_outline.svg';
  static const String liveFilled = '$_p/live_filled.svg';
  static const String inboxOutline = '$_p/inbox_outline.svg';
  static const String inboxFilled = '$_p/inbox_filled.svg';

  /// The Create pill, red with its offset shadow (multicolour, untinted).
  static const String create = 'assets/icons/nav/create.svg';

  static const double iconSize = 26;
  static const Size createSize = Size(54, 36);
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

  /// SVG asset paths ([KNavIcons]): outline when inactive, filled when
  /// active.
  final String icon;
  final String activeIcon;
  final String label;

  /// The centred Create action, drawn as the red pill asset with no visible
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

class _NavButton extends StatefulWidget {
  const new({required this.item, required this.selected, required this.onTap});

  final KBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: _bounceDuration,
  );

  static const _bounceDuration = Duration(milliseconds: 400);

  /// Becoming active: a short squash-and-pop (owner's bar), skipped when
  /// the platform asks to reduce motion.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0.8,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.8,
        end: 1.15,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.15,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 35,
    ),
  ]).animate(_bounce);

  @override
  void didUpdateWidget(_NavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected &&
        !oldWidget.selected &&
        KMotion.of(context, _bounceDuration) > Duration.zero) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = widget.item;
    final selected = widget.selected;
    // D49/D56: the active item is its filled icon with a `textPrimary`
    // label; inactive items are outline icons with `textSecondary` labels.
    final color = selected ? p.textPrimary : p.textSecondary;

    final Widget icon;
    if (item.prominent) {
      icon = SvgPicture.asset(
        item.icon,
        width: KNavIcons.createSize.width,
        height: KNavIcons.createSize.height,
        excludeFromSemantics: true,
      );
    } else {
      final asset = selected ? item.activeIcon : item.icon;
      icon = ScaleTransition(
        scale: _scale,
        child: SvgPicture.asset(
          asset,
          key: ValueKey(asset),
          width: KNavIcons.iconSize,
          height: KNavIcons.iconSize,
          excludeFromSemantics: true,
          theme: SvgTheme(currentColor: color),
        ),
      );
    }

    final visual = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
      onTap: widget.onTap,
      child: InkResponse(
        onTap: widget.onTap,
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
