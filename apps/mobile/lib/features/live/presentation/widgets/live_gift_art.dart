import 'dart:async';
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
/// off»): an effect's movie is drawn whole — its view box scaled to
/// *contain* inside the safe area (aspect kept, centred, never cropped) on
/// any phone, and nothing it draws leaves that box. The player used to get
/// the whole screen with sprites allowed past the view box, so a movie
/// whose art runs over its box (or a screen narrower than the movie's
/// aspect) was cut at the edges.
class KGiftMovieFrame extends StatelessWidget {
  const new({required this.viewBox, required this.child, super.key});

  /// The movie's own size (SVGA `viewBoxWidth` × `viewBoxHeight`).
  final Size viewBox;
  final Widget child;

  /// The rect [viewBox] takes inside [area]: contained and centred.
  static Rect fit(Size viewBox, Rect area) {
    if (viewBox.isEmpty || area.isEmpty) return area;
    final size = applyBoxFit(BoxFit.contain, viewBox, area.size).destination;
    return Alignment.center.inscribe(size, area);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, box) {
        final rect = fit(viewBox, Offset.zero & box.biggest);
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: ClipRect(child: child),
            ),
          ],
        );
      },
    ),
  );
}

/// The large effect of a big gift. The image pops in the centre at once
/// (grows in, holds, fades out over [duration]); when the gift has an SVGA
/// — the hosted [animationUrl] (D126, from the device cache or downloaded
/// now) or the bundled [animationKey] — it plays over the whole screen,
/// once, with the sound inside the SVGA ([GiftEffectSound]). A download
/// that fails or takes longer than [animationWait] skips the animation for
/// this send (the download goes on for the next one). With reduced motion
/// the image just shows. [onHold] runs when an SVGA is being fetched or
/// played (the effect then lasts until it ends, not [duration]); [onDone]
/// runs once when the effect is over; the
/// decoded frames and the sound are released on dispose. Never takes taps.
class KGiftEffect extends StatefulWidget {
  const new({
    required this.assetKey,
    required this.animationKey,
    required this.duration,
    super.key,
    this.imageUrl,
    this.animationUrl,
    this.onHold,
    this.onDone,
    this.size = 220,
  });

  final String assetKey;
  final String? animationKey;
  final String? imageUrl;
  final String? animationUrl;
  final Duration duration;
  final VoidCallback? onHold;
  final VoidCallback? onDone;
  final double size;

  /// How long the effect waits for the SVGA before it gives up on it.
  static const animationWait = Duration(seconds: 6);

  /// Widget tests and goldens skip SVGA decoding (it runs outside fake
  /// time); set by `test/flutter_test_config.dart`.
  static bool animate = true;

  @override
  State<KGiftEffect> createState() => _KGiftEffectState();
}

class _KGiftEffectState extends State<KGiftEffect>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// The still pop; it holds at [_hold] while an SVGA may still come.
  late final AnimationController _still = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  static const _hold = 0.8;
  SVGAAnimationController? _svga;
  GiftEffectSound? _sound;
  bool _started = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The pop has ended (not merely paused at the hold): the effect is over.
    _still.addStatusListener((status) {
      if (status == AnimationStatus.completed && _still.value >= 1) _finish();
    });
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
    final still = MediaQuery.disableAnimationsOf(context);
    final wantsMovie =
        KGiftEffect.animate &&
        !still &&
        (widget.animationUrl != null ||
            KGiftAssets.animation(widget.animationKey) != null);
    if (still) {
      _still.value = 0.5;
      _finishAfter(widget.duration);
    } else if (wantsMovie) {
      widget.onHold?.call();
      _still.animateTo(_hold);
      unawaited(_loadMovie());
    } else {
      _still.forward();
    }
  }

  Timer? _stillTimer;

  void _finishAfter(Duration d) {
    _stillTimer = Timer(d, _finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    unawaited(_sound?.stop());
    widget.onDone?.call();
  }

  /// No SVGA after all: the image finishes its pop.
  void _stillOnly() {
    if (!mounted || _done) return;
    _still.forward();
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
      if (bytes == null) return _stillOnly();
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
        _sound = sound;
      });
      sound.onFrame(0);
      await svga.forward();
      _finish();
    } on Object catch (e) {
      // A broken file: the image plays instead.
      debugPrint(
        'KGiftEffect(${widget.animationUrl ?? widget.animationKey}): $e',
      );
      _stillOnly();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stillTimer?.cancel();
    unawaited(_sound?.stop());
    _still.dispose();
    // Releases the decoded frames (the movie is auto-released).
    _svga?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svga = _svga;
    if (svga != null) {
      final params = svga.videoItem?.params;
      return IgnorePointer(
        child: KGiftMovieFrame(
          viewBox: params == null
              ? Size.zero
              : Size(params.viewBoxWidth, params.viewBoxHeight),
          child: SVGAImage(svga, allowDrawingOverflow: false),
        ),
      );
    }
    return IgnorePointer(
      child: Center(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _still,
            builder: (context, child) {
              final t = _still.value;
              // Grow in (first quarter), hold, fade out (last fifth).
              final scale = t < 0.25
                  ? 0.5 + Curves.easeOutBack.transform(t / 0.25) * 0.5
                  : 1.0;
              final opacity = t < 0.15
                  ? t / 0.15
                  : t > _hold
                  ? (1 - t) / 0.2
                  : 1.0;
              return Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: KGiftImage(
              widget.assetKey,
              imageUrl: widget.imageUrl,
              size: widget.size * 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
