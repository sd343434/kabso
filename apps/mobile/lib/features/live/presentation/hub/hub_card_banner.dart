import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D248 (owner, ref 376): the live hub's card-size banner — one grid cell,
/// the live card's exact size and corners, the picture (720 × 805, the
/// card's aspect, `placement=hub_card`) cover-fitted with its own text.
///
/// - Several banners take turns in the one cell: a cross-fade every
///   [interval], not with reduce motion and not while the hub is hidden
///   ([TickerMode] off). (Simpler than repeating it every N rows, and the
///   rooms' order never moves.)
/// - A tap calls [onOpen] for a banner whose link the app can open
///   ([canOpen]); others are not buttons.
/// - An optional title sits at the bottom like a live card's title.
///
/// Renders nothing for an empty list.
class KHubCardBanner extends StatefulWidget {
  const new({
    required this.banners,
    super.key,
    this.onOpen,
    this.canOpen,
    this.interval = defaultInterval,
  });

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onOpen;
  final bool Function(HomeBanner banner)? canOpen;
  final Duration interval;

  static const defaultInterval = Duration(seconds: 5);

  static const cellKey = Key('hubCardBanner');
  static Key pageKey(String id) => Key('hubCardBanner.page.$id');

  /// Screenshot harnesses only: loads a banner's picture from elsewhere
  /// than the network (tests have none).
  @visibleForTesting
  static ImageProvider Function(String url)? imageForTesting;

  @override
  State<KHubCardBanner> createState() => _KHubCardBannerState();
}

class _KHubCardBannerState extends State<KHubCardBanner> {
  Timer? _timer;
  int _index = 0;

  int get _count => widget.banners.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void didUpdateWidget(KHubCardBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = [for (final b in widget.banners) b.id];
    final oldIds = [for (final b in oldWidget.banners) b.id];
    if (!listEquals(ids, oldIds)) _index = 0;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (_count <= 1 || MediaQuery.disableAnimationsOf(context)) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      setState(() => _index = (_index + 1) % _count);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final index = _index % banners.length;
    final banner = banners[index];
    final open = widget.onOpen;
    final can = open != null && (widget.canOpen?.call(banner) ?? true);
    final title = banner.title?.trim();
    final label = title == null || title.isEmpty
        ? l10n.homeBannerSemantics(index + 1, banners.length)
        : l10n.homeBannerTitledSemantics(title, index + 1, banners.length);
    return ClipRRect(
      key: KHubCardBanner.cellKey,
      borderRadius: BorderRadius.circular(KLiveGrid.radius),
      child: AnimatedSwitcher(
        duration: KMotion.of(context, KMotion.slow),
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: Semantics(
          key: KHubCardBanner.pageKey(banner.id),
          button: can,
          label: label,
          container: true,
          child: ExcludeSemantics(
            child: _CardPage(
              banner: banner,
              title: title,
              onTap: can ? () => open(banner) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The decode width of a card banner: the live card's physical width.
int _cacheWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width /
            2 *
            MediaQuery.devicePixelRatioOf(context))
        .round();

class _CardPage extends StatelessWidget {
  const new({required this.banner, this.title, this.onTap});

  final HomeBanner banner;
  final String? title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final placeholder = ColoredBox(color: p.surfaceRaised);
    final text = title;
    return Material(
      color: p.surfaceRaised,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // D248c: an animated WebP plays; Flutter's `Image` pauses it off
          // screen, in the background and with reduce motion (first
          // frame). Decoded at the cell's width, not 720 px.
          Image(
            image: ResizeImage.resizeIfNeeded(
              _cacheWidth(context),
              null,
              KHubCardBanner.imageForTesting?.call(banner.imageUrl) ??
                  NetworkImage(banner.imageUrl),
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (_, child, frame, sync) =>
                frame == null && !sync ? placeholder : child,
            errorBuilder: (_, _, _) => placeholder,
          ),
          if (text != null && text.isNotEmpty)
            PositionedDirectional(
              start: KSpacing.sm,
              end: KSpacing.sm,
              bottom: KSpacing.sm,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: KLiveGrid.maxTextScale,
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // As a live card's title.
                  style: context.textStyles.bodyStrong.copyWith(
                    color: KPalette.dark.textPrimary,
                    fontSize: 12.5,
                    shadows: const [
                      Shadow(
                        color: Color(0x80000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
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
