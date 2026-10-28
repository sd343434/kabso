import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_effect_sound.dart';
import 'package:material_ui/material_ui.dart';

/// Where the owner's gift files go (CP-020, assets/gifts/PROVENANCE.md):
/// the server's `assetKey` / `animationKey` name them. Keys outside the
/// contract's pattern (or climbing up with `..`) name nothing. Gifts with
/// art hosted on the server (`imageUrl` / `animationUrl`, D126) use that
/// first; these bundled files are the fallback.
abstract final class KGiftAssets {
  static final _key = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_./-]{0,79}$');

  static bool _valid(String key) => _key.hasMatch(key) && !key.contains('..');

  /// The static image of `assetKey`, or null for a key the app refuses.
  static String? image(String assetKey) =>
      _valid(assetKey) ? 'assets/gifts/$assetKey.png' : null;

  /// The SVGA effect of `animationKey`, or null.
  static String? animation(String? animationKey) =>
      animationKey != null && _valid(animationKey)
      ? 'assets/gifts/anim/$animationKey.svga'
      : null;
}

/// A gift's hosted image ([url], D126) through [GiftArtCache]: downloaded
/// once, then read from the device. A failure is not remembered by the
/// image cache, so the next build tries again.
@immutable
class GiftArtImage extends ImageProvider<GiftArtImage> {
  const new(this.url);

  final String url;

  @override
  Future<GiftArtImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    GiftArtImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_load(key, decode));

  Future<ImageInfo> _load(GiftArtImage key, ImageDecoderCallback decode) async {
    try {
      final bytes = await GiftArtCache.instance.load(url);
      final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      final frame = await codec.getNextFrame();
      codec.dispose();
      return ImageInfo(image: frame.image);
    } on Object {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) => other is GiftArtImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'GiftArtImage("$url")';
}

/// A gift's static image at [size] (square): the hosted [imageUrl] (D126),
/// else the bundled `assetKey`, else Kabso's gift box, faded — never an
/// error. Decorative: the caller labels it.
class KGiftImage extends StatelessWidget {
  const new(this.assetKey, {super.key, this.imageUrl, this.size = 48});

  final String assetKey;

  /// The hosted image, or null: the bundled one.
  final String? imageUrl;
  final double size;

  /// The fallback, for tests.
  static const fallbackKey = Key('gift.image.fallback');

  /// The hosted image, for tests.
  static const networkKey = Key('gift.image.network');

  @override
  Widget build(BuildContext context) {
    final fallback = Opacity(
      key: fallbackKey,
      opacity: 0.45,
      child: Image.asset(
        KabsoArt.giftBox.asset,
        width: size,
        height: size,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
      ),
    );
    final path = KGiftAssets.image(assetKey);
    final bundled = path == null
        ? fallback
        : Image.asset(
            path,
            width: size,
            height: size,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => fallback,
          );
    final url = imageUrl;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: url == null || !GiftArtCache.allowed(url)
            ? bundled
            : Image(
                key: networkKey,
                image: GiftArtImage(url),
                width: size,
                height: size,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => bundled,
              ),
      ),
    );
  }
}

/// D145 (owner: «big gift animations are larger than the screen and cut
/// off»): an effect's movie is drawn whole on any phone, its aspect kept,
/// and nothing it draws leaves its frame.
///
/// D145c (owner, device: the angel's wings and legs still cut off): what
/// is fitted is the movie's *drawn* area ([bounds]), not only its view
/// box. A full-screen cinematic such as `angel_warrior` (view box
/// 750 × 1624) paints its frames 916 × 1628 from x = −83: D145 clipped
/// those 83 units on each side (the wings at the edges).
///
/// D145d (owner, device: an empty band under the effect): the drawn area
/// takes the screen's **full width** (nothing cut at the sides) and its
/// **bottom sits on the screen's bottom edge** — through the bottom safe
/// area and behind the bottom bar (the effect never takes taps); its top
/// lands wherever the movie's height puts it. No safe-area inset: the
/// frame fills the whole screen it is given.
class KGiftMovieFrame extends StatelessWidget {
  const new({
    required this.viewBox,
    required this.child,
    super.key,
    this.bounds,
  });

  /// The movie's own size (SVGA `viewBoxWidth` × `viewBoxHeight`).
  final Size viewBox;

  /// What the movie draws, in view-box units ([movieBounds]); null: the
  /// view box.
  final Rect? bounds;

  /// The movie, drawn into the view box (overflow allowed: the frame clips
  /// at [bounds]).
  final Widget child;

  /// [bounds] scaled to [area]'s full width, its bottom on [area]'s
  /// bottom (D145d); returns (the drawn area's rect, the view box's rect)
  /// on screen. The top may be above [area] for a movie taller than it.
  static (Rect, Rect) layout(Size viewBox, Rect bounds, Rect area) {
    final box = Offset.zero & viewBox;
    final drawn = bounds.isEmpty ? box : bounds.expandToInclude(box);
    if (drawn.isEmpty || area.isEmpty) return (area, area);
    final scale = area.width / drawn.width;
    final height = drawn.height * scale;
    final outer = Rect.fromLTWH(
      area.left,
      area.bottom - height,
      area.width,
      height,
    );
    final inner = Rect.fromLTWH(
      outer.left - drawn.left * scale,
      outer.top - drawn.top * scale,
      viewBox.width * scale,
      viewBox.height * scale,
    );
    return (outer, inner);
  }

  /// What [movie] paints over all its frames, in view-box units: the
  /// union of its bitmaps' transformed frames (the player draws each at
  /// `0, 0, layout.width, layout.height` under the frame's transform),
  /// at least the view box. A stray sprite far off the canvas does not
  /// shrink the movie: the area stops at half a view box beyond each edge.
  static Rect movieBounds(MovieEntity movie) {
    final p = movie.params;
    final box = Rect.fromLTWH(0, 0, p.viewBoxWidth, p.viewBoxHeight);
    if (box.isEmpty) return box;
    Rect? drawn;
    for (final sprite in movie.sprites) {
      if (sprite.imageKey.isEmpty) continue;
      Rect? last;
      for (final f in sprite.frames) {
        final w = f.layout.width;
        final h = f.layout.height;
        if (w <= 0 || h <= 0 || (f.hasAlpha() && f.alpha <= 0)) continue;
        final Rect r;
        if (f.hasTransform()) {
          final t = f.transform;
          final xs = [0.0, t.a * w, t.c * h, t.a * w + t.c * h];
          final ys = [0.0, t.b * w, t.d * h, t.b * w + t.d * h];
          r = Rect.fromLTRB(
            t.tx + xs.reduce(math.min),
            t.ty + ys.reduce(math.min),
            t.tx + xs.reduce(math.max),
            t.ty + ys.reduce(math.max),
          );
        } else {
          r = Rect.fromLTWH(0, 0, w, h);
        }
        if (r == last) continue;
        last = r;
        drawn = drawn == null ? r : drawn.expandToInclude(r);
      }
    }
    if (drawn == null) return box;
    final limit = Rect.fromLTRB(
      -box.width / 2,
      -box.height / 2,
      box.width * 1.5,
      box.height * 1.5,
    );
    return box.expandToInclude(drawn.intersect(limit));
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: LayoutBuilder(
      builder: (context, box) {
        final (outer, inner) = layout(
          viewBox,
          bounds ?? Offset.zero & viewBox,
          Offset.zero & box.biggest,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRect(
              rect: outer,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fromRect(
                      rect: inner.shift(-outer.topLeft),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The full-screen effect of an animated gift: its SVGA — the hosted
/// [animationUrl] (D126, from the device cache or downloaded now) or the
/// bundled [animationKey] — plays once over the room, full width and
/// standing on the screen's bottom edge ([KGiftMovieFrame], D145d), with
/// the sound inside the SVGA
/// ([GiftEffectSound]).
///
/// D145c (owner: «the gift's static picture floats mid-screen for ~2 s,
/// then the SVGA plays»): nothing is drawn until the movie is ready — the
/// strip (with the gift's small picture) is already on screen; the panel
/// prefetches the selected gift's SVGA so it is usually ready at once. A
/// download that fails or takes longer than [animationWait] skips the
/// effect for this send (the download goes on for the next one), as does
/// reduced motion. [onHold] runs when the SVGA is being fetched or played
/// (the effect then lasts until it ends); [onDone] runs once when the
/// effect is over; the decoded frames and the sound are released on
/// dispose. Never takes taps.
class KGiftEffect extends StatefulWidget {
  const new({
    required this.animationKey,
    super.key,
    this.animationUrl,
    this.onHold,
    this.onDone,
  });

  final String? animationKey;
  final String? animationUrl;
  final VoidCallback? onHold;
  final VoidCallback? onDone;

  /// How long the effect waits for the SVGA before it gives up on it.
  static const animationWait = Duration(seconds: 8);

  /// Widget tests and goldens skip SVGA decoding (it runs outside fake
  /// time); set by `test/flutter_test_config.dart`.
  static bool animate = true;

  @override
  State<KGiftEffect> createState() => _KGiftEffectState();
}

class _KGiftEffectState extends State<KGiftEffect>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  SVGAAnimationController? _svga;
  Rect? _bounds;
  GiftEffectSound? _sound;
  bool _started = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The sound never plays in the background (the picture may go on).
    if (state != AppLifecycleState.resumed) unawaited(_sound?.stop());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Tests: the room's timer ends the effect ([LiveGiftEffects.bigTime]).
    if (!KGiftEffect.animate) return;
    final hasMovie =
        widget.animationUrl != null ||
        KGiftAssets.animation(widget.animationKey) != null;
    if (MediaQuery.disableAnimationsOf(context) || !hasMovie) {
      // Nothing to play (reduced motion: the strip says it).
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    widget.onHold?.call();
    unawaited(_loadMovie());
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    unawaited(_sound?.stop());
    widget.onDone?.call();
  }

  Future<Uint8List?> _movieBytes() async {
    final url = widget.animationUrl;
    if (url != null) {
      try {
        return await GiftArtCache.instance
            .load(url)
            .timeout(KGiftEffect.animationWait);
      } on Object catch (e) {
        debugPrint('KGiftEffect($url): $e');
      }
    }
    final path = KGiftAssets.animation(widget.animationKey);
    if (path == null) return null;
    try {
      return (await rootBundle.load(path)).buffer.asUint8List();
    } on Object {
      return null;
    }
  }

  Future<void> _loadMovie() async {
    try {
      final bytes = await _movieBytes();
      if (!mounted) return;
      if (bytes == null) return _finish();
      final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
      if (!mounted) {
        movie.dispose();
        return;
      }
      final sound = GiftEffectSound.fromMovie(movie);
      final svga = SVGAAnimationController(vsync: this)
        ..muted = true
        ..videoItem = movie;
      if (!sound.isEmpty) {
        svga.addListener(() => sound.onFrame(svga.currentFrame));
      }
      setState(() {
        _svga = svga;
        _bounds = KGiftMovieFrame.movieBounds(movie);
        _sound = sound;
      });
      sound.onFrame(0);
      await svga.forward();
      _finish();
    } on Object catch (e) {
      // A broken file: no effect (the strip has shown the gift).
      debugPrint(
        'KGiftEffect(${widget.animationUrl ?? widget.animationKey}): $e',
      );
      _finish();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sound?.stop());
    // Releases the decoded frames (the movie is auto-released).
    _svga?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svga = _svga;
    final params = svga?.videoItem?.params;
    if (svga == null || params == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: KGiftMovieFrame(
        viewBox: Size(params.viewBoxWidth, params.viewBoxHeight),
        bounds: _bounds,
        // The frame clips at the drawn area; the player may draw past the
        // view box into it.
        child: SVGAImage(svga),
      ),
    );
  }
}
