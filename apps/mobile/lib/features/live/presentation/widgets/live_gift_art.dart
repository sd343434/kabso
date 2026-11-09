import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/svga/svga_engine.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_effect_sound.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_video_effect.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

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

/// D317 (owner, from a device: the 500 000-coin «الملاك المحارب»
/// `angel_warrior`, an SVGA, showed the room's header above it and looked
/// cropped — «the full-screen gift must appear filling the whole screen»):
/// a **full-screen** SVGA (the gift's «شاشة كاملة» badge, D289, or a
/// portrait canvas at least 1.5 times as tall as wide — the panel's own
/// [looksFullScreen] rule) is drawn like D309's plain MP4: its own canvas
/// (the view box) scaled to **cover** the whole live screen, centred, its
/// aspect kept — a canvas of another shape loses equal strips at two
/// opposite edges, never leaves a band of the room. What the movie leaves
/// transparent stays transparent. Other effects keep [KGiftMovieFrame].
class KGiftFullScreenFrame extends StatelessWidget {
  const new({required this.viewBox, required this.child, super.key});

  /// The movie's canvas (SVGA `viewBoxWidth` × `viewBoxHeight`).
  final Size viewBox;

  /// The movie, drawn into the view box.
  final Widget child;

  static const frameKey = Key('gift.effect.fullScreen');

  /// The panel's «شاشة كاملة» rule (`looksFullscreen`, D289): a portrait
  /// canvas at least this many times as tall as wide.
  static const minAspect = 1.5;

  /// Whether a canvas of [viewBox] is a full-screen one by its shape.
  static bool looksFullScreen(Size viewBox) =>
      !viewBox.isEmpty && viewBox.height >= viewBox.width * minAspect;

  /// The view box's rect on a [screen]: scaled to cover it, centred.
  static Rect layout(Size viewBox, Size screen) {
    if (viewBox.isEmpty || screen.isEmpty) return Offset.zero & screen;
    final scale = math.max(
      screen.width / viewBox.width,
      screen.height / viewBox.height,
    );
    final w = viewBox.width * scale;
    final h = viewBox.height * scale;
    return Rect.fromLTWH((screen.width - w) / 2, (screen.height - h) / 2, w, h);
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: frameKey,
    child: LayoutBuilder(
      builder: (context, box) => ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRect(
              rect: layout(viewBox, box.biggest),
              child: child,
            ),
          ],
        ),
      ),
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
///
/// v1.46-live (D207, CONVENTIONS §10.66): the hosted effect may be an MP4 —
/// a plain video played as is, or side-by-side alpha composited by a shader
/// ([GiftVideoView]) — and the gift may have an MP3 ([audioUrl]) played with
/// it, or alone. Every sound (the SVGA's own, the MP4's, the MP3) plays only
/// while [soundOn] (the viewer's «المؤثرات الصوتية» setting and, D225,
/// «كتم أصوات الهدايا») and the app is in the foreground. What the device
/// cannot play (an unknown format, side-by-side without shader support, a
/// broken file) is skipped: the strip's picture is all that shows.
class KGiftEffect extends StatefulWidget {
  const new({
    required this.animationKey,
    super.key,
    this.animationUrl,
    this.animationFormat,
    this.animationAlpha,
    this.audioUrl,
    this.audioDurationMs,
    this.soundOn = true,
    this.fullScreen = false,
    this.onHold,
    this.onDone,
  });

  final String? animationKey;

  /// D317: the gift is marked «شاشة كاملة» (D289): its SVGA covers the
  /// whole screen ([KGiftFullScreenFrame]); a portrait canvas does anyway.
  final bool fullScreen;
  final String? animationUrl;

  /// v1.46-live (D207): [animationUrl]'s format (null: an older API, SVGA)
  /// and an MP4's transparency.
  final GiftAnimationFormat? animationFormat;
  final GiftVideoAlpha? animationAlpha;

  /// v1.46-live (D207): the gift's hosted MP3 and its length.
  final String? audioUrl;
  final int? audioDurationMs;

  /// Whether sound may play (the settings and the live's switch).
  final bool soundOn;
  final VoidCallback? onHold;
  final VoidCallback? onDone;

  /// How long a sound-only effect lasts without a length from the server.
  static const soundOnlyTime = Duration(seconds: 5);

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

  /// D272b: the effect's file read by the shared engine, and (no vector
  /// shapes) its playback: the pictures' reader, the frame shown, the clock.
  SvgaDoc? _doc;
  SvgaReader? _reader;
  Ticker? _ticker;
  Duration? _playStart;
  int _frame = 0;
  GiftEffectSound? _sound;
  GiftEffectSound? _mp3;
  VideoPlayerController? _video;
  ui.FragmentShader? _shader;
  Timer? _soundTimer;
  bool _started = false;
  bool _done = false;

  GiftEffectKind get _kind => giftEffectKind(
    animationUrl: widget.animationUrl,
    animationFormat: widget.animationFormat,
    animationAlpha: widget.animationAlpha,
    hasBundledSvga: KGiftAssets.animation(widget.animationKey) != null,
    audioUrl: widget.audioUrl,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The sound never plays in the background (the picture may go on).
    if (state != AppLifecycleState.resumed) {
      unawaited(_sound?.stop());
      unawaited(_mp3?.stop());
      unawaited(_video?.setVolume(0));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Tests: the room's timer ends the effect ([LiveGiftEffects.bigTime]).
    if (!KGiftEffect.animate) return;
    final kind = _kind;
    final still = MediaQuery.disableAnimationsOf(context);
    if (kind == GiftEffectKind.none ||
        (still && kind != GiftEffectKind.soundOnly)) {
      // Nothing to play (reduced motion: the strip says it).
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    widget.onHold?.call();
    unawaited(switch (kind) {
      GiftEffectKind.svga => _loadMovie(),
      GiftEffectKind.mp4 || GiftEffectKind.mp4Alpha => _loadVideo(
        alpha: kind == GiftEffectKind.mp4Alpha,
      ),
      GiftEffectKind.soundOnly => _soundOnly(),
      GiftEffectKind.none => Future<void>.value(),
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _soundTimer?.cancel();
    unawaited(_sound?.stop());
    unawaited(_mp3?.stop());
    widget.onDone?.call();
  }

  /// v1.46-live (D207): starts the gift's MP3 (from the device cache or
  /// downloaded now) when sound may play; never throws.
  Future<void> _startMp3() async {
    final url = widget.audioUrl;
    if (url == null || !widget.soundOn) return;
    try {
      final bytes = await GiftArtCache.instance
          .load(url)
          .timeout(KGiftEffect.animationWait);
      if (!mounted || _done) return;
      final sound = GiftEffectSound([
        GiftSoundClip(key: url, startFrame: 0, endFrame: 1 << 30, bytes: bytes),
      ]);
      _mp3 = sound;
      sound.onFrame(0);
    } on Object catch (e) {
      debugPrint('KGiftEffect($url): $e');
    }
  }

  /// v1.46-live (D207): a gift with only an MP3 — nothing drawn; the effect
  /// lasts the sound's length.
  Future<void> _soundOnly() async {
    if (!widget.soundOn) return _finish();
    await _startMp3();
    if (!mounted || _done) return;
    final ms = widget.audioDurationMs;
    _soundTimer = Timer(
      ms == null ? KGiftEffect.soundOnlyTime : Duration(milliseconds: ms),
      _finish,
    );
  }

  /// v1.46-live (D207): an MP4 effect from the device cache (downloaded now
  /// when needed), played once; side by side through the alpha shader, or
  /// skipped where the shader cannot run.
  Future<void> _loadVideo({required bool alpha}) async {
    final url = widget.animationUrl!;
    VideoPlayerController? video;
    try {
      ui.FragmentShader? shader;
      if (alpha) {
        final program = await GiftAlphaShader.load();
        if (program == null) {
          // No compositing here: no black box over the room (the picture is
          // in the strip); the sound still plays.
          await _startMp3();
          _soundTimer = Timer(
            Duration(milliseconds: widget.audioDurationMs ?? 0),
            _finish,
          );
          return;
        }
        shader = program.fragmentShader();
      }
      final path = await GiftArtCache.instance
          .path(url)
          .timeout(KGiftEffect.animationWait);
      if (!mounted) {
        shader?.dispose();
        return;
      }
      video = giftVideoController(path);
      await video.initialize().timeout(KGiftEffect.animationWait);
      if (!mounted || _done) {
        shader?.dispose();
        await video.dispose();
        return;
      }
      // The MP4's own sound only when the gift has no MP3 (the MP3 is the
      // gift's sound then).
      await video.setVolume(
        widget.soundOn &&
                widget.audioUrl == null &&
                (WidgetsBinding.instance.lifecycleState ??
                        AppLifecycleState.resumed) ==
                    AppLifecycleState.resumed
            ? 1
            : 0,
      );
      final controller = video;
      controller.addListener(() {
        final v = controller.value;
        if (v.hasError) {
          _finish();
        } else if (v.isInitialized &&
            !v.isPlaying &&
            v.duration > Duration.zero &&
            v.position >= v.duration) {
          _finish();
        }
      });
      setState(() {
        _video = controller;
        _shader = shader;
      });
      unawaited(_startMp3());
      await controller.play();
    } on Object catch (e) {
      // Not playable on this device (or not downloaded in time): the strip
      // has shown the gift.
      debugPrint('KGiftEffect($url): $e');
      if (_video == null) await video?.dispose();
      _finish();
    }
  }

  /// The effect's SVGA source for the shared engine: the hosted file, else
  /// the bundled one.
  String? get _source {
    final url = widget.animationUrl;
    if (url != null) return url;
    final path = KGiftAssets.animation(widget.animationKey);
    return path == null ? null : SvgaDocs.asset(path);
  }

  /// D272b (owner: «حاول اصلاح المشكلة بالكامل»): the SVGA through the
  /// app's one engine — read on another isolate (usually already, as the
  /// gift arrived: `LiveGiftEffects` reads it ahead), its pictures decoded
  /// at the size they are drawn; a big clip drawn from a window of about a
  /// second of decoded pictures (released behind), a small one from its
  /// kept pictures (a combo replays at once). It starts only once its first
  /// second is ready, within [KGiftEffect.animationWait] (else skipped; the
  /// file stays read for the next send). A file with vector shapes or clip
  /// paths plays on the package's player (same reading and decoding).
  Future<void> _loadMovie() async {
    final source = _source;
    if (source == null) return _finish();
    final view = View.of(context);
    final screen = view.physicalSize.width;
    final deadline = Stopwatch()..start();
    Duration left() {
      final rest = KGiftEffect.animationWait - deadline.elapsed;
      return rest > Duration.zero ? rest : Duration.zero;
    }

    try {
      final doc = await SvgaDocs.doc(source).timeout(left());
      if (!mounted) return;
      if (doc == null) return _finish();
      final bounds = doc.bounds ?? Offset.zero & doc.viewBox;
      // Device pixels per canvas unit: the drawn area takes the screen's
      // width (D145d).
      final scale = screen / math.max(1, bounds.width);
      // v1.46-live (D207): the SVGA's own sound only while sound may play
      // and the gift has no MP3 of its own.
      final sound = widget.soundOn && widget.audioUrl == null
          ? GiftEffectSound.fromSvga(doc.sounds)
          : GiftEffectSound(const []);
      if (doc.vector) {
        final movie = await doc.toMovie(scale).timeout(left());
        if (!mounted || _done) {
          movie.dispose();
          return;
        }
        unawaited(_startMp3());
        final svga = SVGAAnimationController(vsync: this)
          ..muted = true
          ..videoItem = movie;
        if (!sound.isEmpty) {
          svga.addListener(() => sound.onFrame(svga.currentFrame));
        }
        setState(() {
          _svga = svga;
          _doc = doc;
          _sound = sound;
        });
        sound.onFrame(0);
        await svga.forward();
        _finish();
        return;
      }
      final live = await SvgaDocs.live(source, scale: scale).timeout(left());
      if (!mounted || _done) return;
      if (live == null) return _finish();
      final reader = SvgaReader(live);
      _reader = reader;
      await reader.want(0).timeout(left());
      if (!mounted || _done) return;
      unawaited(_startMp3());
      setState(() {
        _doc = doc;
        _frame = 0;
        _sound = sound;
      });
      sound.onFrame(0);
      _playStart = null;
      (_ticker ??= createTicker(_tick)).start();
    } on Object catch (e) {
      // Not ready in time, or a broken file: no effect (the strip has shown
      // the gift; a slow file goes on being read for the next send).
      debugPrint('KGiftEffect($source): $e');
      _finish();
    }
  }

  /// One frame of the engine's clip: the clock decides the frame (and the
  /// sound); a picture not decoded yet keeps the last frame a moment.
  void _tick(Duration elapsed) {
    final doc = _doc;
    final reader = _reader;
    if (doc == null || reader == null || _done) return;
    final start = _playStart ??= elapsed;
    final t = elapsed - start;
    if (t >= doc.duration) {
      _ticker?.stop();
      _finish();
      return;
    }
    final frame = math.min(
      doc.frameCount - 1,
      (t.inMicroseconds * doc.fps / 1e6).floor(),
    );
    _sound?.onFrame(frame);
    unawaited(reader.want(frame));
    if (frame != _frame && reader.ready(frame)) {
      setState(() => _frame = frame);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _soundTimer?.cancel();
    unawaited(_mp3?.stop());
    unawaited(_video?.dispose());
    _shader?.dispose();
    unawaited(_sound?.stop());
    _ticker?.dispose();
    _reader?.dispose();
    // Releases the decoded frames (the movie is auto-released).
    _svga?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    if (video != null && video.value.isInitialized) {
      final size = video.value.size;
      final sideBySide = _shader != null;
      // D309: a plain video fills the whole screen (D207: «played full
      // screen as is»); a side-by-side one stands on the bottom edge.
      return IgnorePointer(
        child: GiftVideoFrame(
          video: size,
          sideBySide: sideBySide,
          movieFrame: (viewBox, child) =>
              KGiftMovieFrame(viewBox: viewBox, child: child),
          child: GiftVideoView(controller: video, shader: _shader),
        ),
      );
    }
    final doc = _doc;
    if (doc == null) return const SizedBox.shrink();
    final svga = _svga;
    final reader = _reader;
    final movie = svga != null
        ? SVGAImage(svga)
        : CustomPaint(
            painter: SvgaFramePainter(
              doc: doc,
              frame: _frame,
              pictures: reader?.pictures ?? const {},
            ),
          );
    // D317: a full-screen gift covers the whole live screen.
    if (widget.fullScreen ||
        KGiftFullScreenFrame.looksFullScreen(doc.viewBox)) {
      return IgnorePointer(
        child: KGiftFullScreenFrame(viewBox: doc.viewBox, child: movie),
      );
    }
    return IgnorePointer(
      child: KGiftMovieFrame(
        viewBox: doc.viewBox,
        bounds: doc.bounds,
        // The frame clips at the drawn area; the clip may draw past the
        // view box into it.
        child: movie,
      ),
    );
  }
}
