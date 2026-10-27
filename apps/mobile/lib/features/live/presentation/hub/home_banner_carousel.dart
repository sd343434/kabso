import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The live hub's promo banners (D124, CONVENTIONS §10.26): a full-width
/// 3:1 carousel with rounded corners (the owner's pictures carry their text,
/// so they are shown whole, never cropped to another shape).
///
/// - Auto-advances every [interval] while more than one banner is shown,
///   always forwards (the pager wraps around), not with reduce motion, not
///   while a finger is on it and not while the hub is hidden (a route above
///   it, another shell tab: [TickerMode] off).
/// - Page dots under the picture's bottom edge when there is more than one.
/// - A tap calls [onOpen] for a banner whose link the app can open
///   ([canOpen]); others are not buttons.
/// - Optional overlay text on the banner's empty side.
///
/// Renders nothing for an empty list (the hub then has no banner).
class KHomeBannerCarousel extends StatefulWidget {
  const new({
    required this.banners,
    super.key,
    this.onOpen,
    this.canOpen,
    this.interval = defaultInterval,
  });

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onOpen;

  /// Whether [onOpen] can do something with this banner (default: yes).
  final bool Function(HomeBanner banner)? canOpen;
  final Duration interval;

  static const defaultInterval = Duration(seconds: 4);

  /// Width : height of every banner (1 500 × 500).
  static const double aspect = 3;

  static const carouselKey = Key('homeBanner.carousel');
  static const dotsKey = Key('homeBanner.dots');
  static Key pageKey(String id) => Key('homeBanner.page.$id');

  /// Screenshot harnesses only: loads a banner's picture from elsewhere
  /// than the network (tests have none).
  @visibleForTesting
  static ImageProvider Function(String url)? imageForTesting;

  @override
  State<KHomeBannerCarousel> createState() => _KHomeBannerCarouselState();
}

class _KHomeBannerCarouselState extends State<KHomeBannerCarousel> {
  /// The pager runs over a long virtual range so it always moves forwards
  /// and can be swiped either way from the start.
  static const _loops = 1000;

  late PageController _controller = _newController();
  Timer? _timer;
  int _pointers = 0;
  late int _page = _initialPage;

  int get _count => widget.banners.length;
  int get _initialPage => _count <= 1 ? 0 : _count * (_loops ~/ 2);

  PageController _newController() => PageController(initialPage: _initialPage);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void didUpdateWidget(KHomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = [for (final b in widget.banners) b.id];
    final oldIds = [for (final b in oldWidget.banners) b.id];
    if (!listEquals(ids, oldIds)) {
      // Another set of banners: start again at the first one.
      _controller.dispose();
      _page = _initialPage;
      _controller = _newController();
    }
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (_count <= 1 || MediaQuery.disableAnimationsOf(context)) return;
    _timer = Timer.periodic(widget.interval, (_) => _advance());
  }

  void _advance() {
    if (!mounted || _pointers > 0 || !_controller.hasClients) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    _controller.animateToPage(
      _page + 1,
      duration: KMotion.of(context, KMotion.slow),
      curve: KMotion.standard,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final count = banners.length;
    final current = _page % count;
    return Column(
      key: KHomeBannerCarousel.carouselKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: KHomeBannerCarousel.aspect,
          child: Listener(
            // Pause while touched: the timer skips its ticks.
            onPointerDown: (_) => _pointers++,
            onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 99),
            onPointerCancel: (_) => _pointers = (_pointers - 1).clamp(0, 99),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KLiveGrid.radius),
              child: PageView.builder(
                controller: _controller,
                itemCount: count <= 1 ? count : count * _loops,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, page) {
                  final index = page % count;
                  final banner = banners[index];
                  final title = banner.title;
                  final open = widget.onOpen;
                  final can =
                      open != null && (widget.canOpen?.call(banner) ?? true);
                  final label = title == null || title.trim().isEmpty
                      ? l10n.homeBannerSemantics(index + 1, count)
                      : l10n.homeBannerTitledSemantics(title, index + 1, count);
                  return Semantics(
                    key: KHomeBannerCarousel.pageKey(banner.id),
                    button: can,
                    label: label,
                    container: true,
                    child: ExcludeSemantics(
                      child: _BannerPage(
                        banner: banner,
                        onTap: can ? () => open(banner) : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (count > 1)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xs),
            child: ExcludeSemantics(
              child: Row(
                key: KHomeBannerCarousel.dotsKey,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: KMotion.of(context, KMotion.fast),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: i == current ? 14 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == current
                            ? context.palette.primary
                            : context.palette.textSecondary.withValues(
                                alpha: 0.35,
                              ),
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BannerPage extends StatelessWidget {
  const new({required this.banner, this.onTap});

  final HomeBanner banner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title = banner.title?.trim();
    final placeholder = ColoredBox(color: p.surfaceRaised);
    return Material(
      color: p.surfaceRaised,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image:
                KHomeBannerCarousel.imageForTesting?.call(banner.imageUrl) ??
                NetworkImage(banner.imageUrl),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (_, child, frame, sync) =>
                frame == null && !sync ? placeholder : child,
            errorBuilder: (_, _, _) => placeholder,
          ),
          if (title != null && title.isNotEmpty)
            Align(
              alignment: banner.titleSide == HomeBannerTitleSide.left
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: KLiveGrid.maxTextScale,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.textStyles.title.copyWith(
                        color: KPalette.dark.textPrimary,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (onTap != null) InkWell(onTap: onTap),
        ],
      ),
    );
  }
}
