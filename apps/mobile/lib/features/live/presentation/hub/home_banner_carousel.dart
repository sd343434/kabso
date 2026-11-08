import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// The live hub's promo banners (D124, CONVENTIONS §10.26): a full-width
/// 3:1 carousel with rounded corners (the owner's pictures carry their text,
/// so they are shown whole, never cropped to another shape).
///
/// - Auto-advances every [interval] while more than one banner is shown,
///   always forwards (the pager wraps around), not with reduce motion, not
///   while a finger is on it and not while the hub is hidden (a route above
///   it, another shell tab: [TickerMode] off).
/// - Page dots under the picture's bottom edge when there is more than one;
///   D248 [overlayIndicator] (the live hub, owner's reference): a thin
///   segmented bar inside the picture's bottom edge instead.
/// - A tap calls [onOpen] for a banner whose link the app can open
///   ([canOpen]); others are not buttons.
/// - Optional overlay text on the banner's empty side.
/// - v1.97-social (D303): an ANIMATED banner plays its animated WebP; a VIDEO
///   banner plays muted and looping only while at least half visible, the
///   app in the foreground and the hub shown ([TickerMode]), its poster until
///   the first frame (and when it cannot play); the carousel stays on a video
///   for its length. With reduced motion only the still (`posterUrl`) shows.
///
/// Renders nothing for an empty list (the hub then has no banner).
class KHomeBannerCarousel extends StatefulWidget {
  const new({
    required this.banners,
    super.key,
    this.onOpen,
    this.canOpen,
    this.interval = defaultInterval,
    this.overlayIndicator = false,
    this.aspect = defaultAspect,
  });

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onOpen;

  /// Whether [onOpen] can do something with this banner (default: yes).
  final bool Function(HomeBanner banner)? canOpen;
  final Duration interval;

  /// D248: the page indicator as a bar inside the picture (the live hub).
  final bool overlayIndicator;

  static const defaultInterval = Duration(seconds: 4);

  /// Width : height of a TASKS / WALLET banner (1 500 × 500).
  static const double defaultAspect = 3;

  /// D248b (owner: «البنر كبير، خذ نفس حجم بنر البيجو»; ref 375 measured
  /// 690 × 138 px = 5.0): the `HOME` banners (the live hub, the Voice rooms
  /// list, the Creator Center) are 5:1, uploaded at 1 500 × 300. Older
  /// 1 500 × 500 pictures are centre-cropped (cover) to it.
  static const double homeAspect = 5;

  /// Width : height of this carousel.
  final double aspect;

  /// D248 (ref 375, 738 px wide ≈ 1.88 px/pt): the indicator bar's segment
  /// per page (16 px), its height (4 px) and its distance from the
  /// picture's bottom edge (12 px).
  static const double indicatorSegment = 8.5;
  static const double indicatorHeight = 2;
  static const double indicatorBottom = 6.4;

  static const carouselKey = Key('homeBanner.carousel');
  static const dotsKey = Key('homeBanner.dots');
  static Key pageKey(String id) => Key('homeBanner.page.$id');

  /// Screenshot harnesses only: loads a banner's picture from elsewhere
  /// than the network (tests have none).
  @visibleForTesting
  static ImageProvider Function(String url)? imageForTesting;

  /// Tests and goldens: whether a VIDEO banner may start its player (the
  /// test host has none; the poster is shown either way until it plays).
  @visibleForTesting
  static bool playVideos = true;

  static Key videoKey(String id) => Key('homeBanner.video.$id');
  static Key stillKey(String id) => Key('homeBanner.still.$id');

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
    // D303: a video stays for its length (at least the usual interval).
    final banner = widget.banners[_page % _count];
    final length = banner.isVideo && banner.durationMs != null
        ? Duration(milliseconds: banner.durationMs!)
        : Duration.zero;
    _timer = Timer(
      length > widget.interval ? length : widget.interval,
      _advance,
    );
  }

  void _advance() {
    if (!mounted) return;
    if (_pointers > 0 ||
        !_controller.hasClients ||
        !TickerMode.valuesOf(context).enabled) {
      _restartTimer();
      return;
    }
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

  /// D248: the pager with the hub's indicator bar over its bottom edge
  /// (ref 375: a translucent track, the current page's segment white).
  Widget _withOverlay({
    required int count,
    required int current,
    required Widget pager,
  }) {
    if (!widget.overlayIndicator || count <= 1) return pager;
    const segment = KHomeBannerCarousel.indicatorSegment;
    return Stack(
      children: [
        Positioned.fill(child: pager),
        Positioned(
          left: 0,
          right: 0,
          bottom: KHomeBannerCarousel.indicatorBottom,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Center(
                child: Container(
                  key: KHomeBannerCarousel.dotsKey,
                  width: segment * count,
                  height: KHomeBannerCarousel.indicatorHeight,
                  decoration: BoxDecoration(
                    color: const Color(0x4DFFFFFF),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  // The segment moves with the pager, from the reading
                  // start (the pager runs right to left in Arabic).
                  child: AnimatedAlign(
                    duration: KMotion.of(context, KMotion.fast),
                    alignment: AlignmentDirectional(
                      -1 + 2 * current / (count - 1),
                      0,
                    ),
                    child: Container(
                      width: segment,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
          aspectRatio: widget.aspect,
          child: Listener(
            // Pause while touched: the timer skips its ticks.
            onPointerDown: (_) => _pointers++,
            onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 99),
            onPointerCancel: (_) => _pointers = (_pointers - 1).clamp(0, 99),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KLiveGrid.radius),
              child: _withOverlay(
                count: count,
                current: current,
                pager: PageView.builder(
                  controller: _controller,
                  itemCount: count <= 1 ? count : count * _loops,
                  onPageChanged: (page) {
                    setState(() => _page = page);
                    _restartTimer();
                  },
                  itemBuilder: (context, page) {
                    final index = page % count;
                    final banner = banners[index];
                    final title = banner.title;
                    final open = widget.onOpen;
                    final can =
                        open != null && (widget.canOpen?.call(banner) ?? true);
                    final label = title == null || title.trim().isEmpty
                        ? l10n.homeBannerSemantics(index + 1, count)
                        : l10n.homeBannerTitledSemantics(
                            title,
                            index + 1,
                            count,
                          );
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
        ),
        if (count > 1 && !widget.overlayIndicator)
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
    Widget picture(String url, {Key? key}) => Image(
      key: key,
      image:
          KHomeBannerCarousel.imageForTesting?.call(url) ?? NetworkImage(url),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (_, child, frame, sync) =>
          frame == null && !sync ? placeholder : child,
      errorBuilder: (_, _, _) => placeholder,
    );
    // D303: reduced motion shows the still only (no animation, no video).
    final still = MediaQuery.disableAnimationsOf(context);
    final media = still
        ? picture(banner.stillUrl, key: KHomeBannerCarousel.stillKey(banner.id))
        : banner.isVideo
        ? _BannerVideo(
            key: KHomeBannerCarousel.videoKey(banner.id),
            url: banner.videoUrl!,
            poster: picture(banner.stillUrl),
          )
        : picture(banner.imageUrl);
    return Material(
      color: p.surfaceRaised,
      child: Stack(
        fit: StackFit.expand,
        children: [
          media,
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

/// D303 (CONVENTIONS §10.114.6): a VIDEO banner — muted, looping, playing only
/// while at least half of it is visible, the app in the foreground and the
/// hub shown; the [poster] until the first frame and whenever it cannot play.
class _BannerVideo extends StatefulWidget {
  const new({required this.url, required this.poster, super.key});

  final String url;
  final Widget poster;

  @override
  State<_BannerVideo> createState() => _BannerVideoState();
}

class _BannerVideoState extends State<_BannerVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _started = false;
  bool _visible = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && KHomeBannerCarousel.playVideos) {
      _started = true;
      unawaited(_load());
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  Future<void> _load() async {
    final url = widget.url;
    final video = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await video.initialize();
      await video.setVolume(0);
      await video.setLooping(true);
      if (!mounted || widget.url != url) {
        await video.dispose();
        return;
      }
      setState(() => _video = video);
      _sync();
    } on Object catch (e) {
      debugPrint('Banner video ($url): $e');
      await video.dispose();
    }
  }

  void _sync() {
    final video = _video;
    if (video == null || !mounted) return;
    final play =
        _visible && _foreground && TickerMode.valuesOf(context).enabled;
    if (play && !video.value.isPlaying) {
      unawaited(video.play());
    } else if (!play && video.value.isPlaying) {
      unawaited(video.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_video?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return VisibilityDetector(
      key: ValueKey('homeBanner.visibility.${widget.url}'),
      onVisibilityChanged: (info) {
        _visible = info.visibleFraction >= 0.5;
        _sync();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.poster,
          if (video != null && video.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: video.value.size.width,
                height: video.value.size.height,
                child: VideoPlayer(video),
              ),
            ),
        ],
      ),
    );
  }
}
