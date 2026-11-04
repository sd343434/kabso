import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:material_ui/material_ui.dart';

/// D258: the VIP art's SVGA engine. Every perk's SVGA (badge, frame, bubble,
/// card, banner, car, mic wave) goes through one shared cache: a file is
/// downloaded once (the gift art cache, kept on the device), decoded once,
/// and each frame is drawn ONCE into a small image at the size it is shown
/// (bucketed), after which the full-size bitmaps are released. A 3.7 MB
/// badge in fifty chat lines is then one set of small frames, and every
/// line shows the same frame of one shared clock (no controller per line).
class VipSvgaClip {
  const new({
    required this.viewBox,
    required this.fps,
    required this.frames,
    required this.scale,
  });

  /// The SVGA's canvas, in its own units.
  final Size viewBox;
  final int fps;

  /// Each frame drawn at [scale] × the canvas.
  final List<ui.Image> frames;
  final double scale;

  Duration get duration =>
      Duration(milliseconds: (frames.length * 1000 / math.max(1, fps)).round());

  /// The relative luminance of [region] (fractions of the canvas) over
  /// [backdrop] across the frames (sampled): its mean, darkest and lightest;
  /// null when it cannot be read.
  Future<({double mean, double min, double max})?> luminanceOf(
    Rect region, {
    Color backdrop = const Color(0xFF000000),
  }) async {
    var sum = 0.0;
    var n = 0;
    var lo = 1.0;
    var hi = 0.0;
    final step = math.max(1, frames.length ~/ 6);
    for (var f = 0; f < frames.length; f += step) {
      final image = frames[f];
      final data = await image.toByteData();
      if (data == null) return null;
      final x0 = (region.left * image.width).floor();
      final x1 = (region.right * image.width).ceil().clamp(x0 + 1, image.width);
      final y0 = (region.top * image.height).floor();
      final y1 = (region.bottom * image.height).ceil().clamp(
        y0 + 1,
        image.height,
      );
      for (var y = y0; y < y1; y += 3) {
        for (var x = x0; x < x1; x += 3) {
          final i = (y * image.width + x) * 4;
          final a = data.getUint8(i + 3) / 255;
          // Premultiplied RGBA: the colour over the backdrop.
          int over(int v, double b) =>
              (v + (1 - a) * b * 255).round().clamp(0, 255);
          final l = Color.fromARGB(
            255,
            over(data.getUint8(i), backdrop.r),
            over(data.getUint8(i + 1), backdrop.g),
            over(data.getUint8(i + 2), backdrop.b),
          ).computeLuminance();
          sum += l;
          n++;
          lo = math.min(lo, l);
          hi = math.max(hi, l);
        }
      }
    }
    return n == 0 ? null : (mean: sum / n, min: lo, max: hi);
  }

  /// The round window in the middle of an avatar frame art: its centre and
  /// diameter as fractions of the canvas — the smallest circle that holds
  /// the whole transparent opening, so a picture that size leaves no gap
  /// anywhere under the frame. D265 (owner: the picture smaller than the
  /// VIP frame's opening): an opening is rarely a circle (the owner's
  /// `svip_1_frame` reaches 0.34 of the canvas towards its corners, 0.29 at
  /// its sides), so D258's widest-row width left the corners open. Measured
  /// along [rays] rays from the canvas centre, each to the first covered
  /// pixel (alpha ≥ 40), the farthest across the sampled frames (the ring
  /// animates; a sparkle that crosses a ray in one frame is outrun in
  /// another); a ray that reaches the canvas edge is a gap in the art, not
  /// the window, and is left out. The plaque that cuts the bottom only
  /// covers more of the picture. Null when the middle is not transparent.
  /// Measured once per clip.
  Future<({Offset centre, double diameter})?> window() =>
      _windows[this] ??= _measureWindow();

  static final _windows =
      Expando<Future<({Offset centre, double diameter})?>>();

  /// The rays [window] measures along.
  static const int rays = 90;

  Future<({Offset centre, double diameter})?> _measureWindow() async {
    if (frames.isEmpty) return null;
    final w = frames.first.width;
    final h = frames.first.height;
    final cx = w / 2;
    final cy = h / 2;
    final side = math.min(w, h);
    // Where a ray starts: past the sparkles that cross the middle.
    final start = side * 0.12;
    final reach = List<double>.filled(rays, -1);
    final step = math.max(1, frames.length ~/ 12);
    for (var f = 0; f < frames.length; f += step) {
      final image = frames[f];
      if (image.width != w || image.height != h) continue;
      final data = await image.toByteData();
      if (data == null) return null;
      bool clear(int x, int y) => data.getUint8((y * w + x) * 4 + 3) < 40;
      if (!clear(cx.round(), cy.round())) continue;
      for (var a = 0; a < rays; a++) {
        final t = a * 2 * math.pi / rays;
        final dx = math.cos(t);
        final dy = math.sin(t);
        var r = start;
        var x = (cx + r * dx).round();
        var y = (cy + r * dy).round();
        if (!clear(x, y)) continue; // a sparkle on this ray now.
        var last = r;
        var open = false;
        while (true) {
          r += 1;
          x = (cx + r * dx).round();
          y = (cy + r * dy).round();
          if (x < 0 || y < 0 || x >= w || y >= h) {
            open = true;
            break;
          }
          if (!clear(x, y)) break;
          last = r;
        }
        if (!open && last > reach[a]) reach[a] = last;
      }
    }
    final points = [
      for (var a = 0; a < rays; a++)
        if (reach[a] > 0)
          Offset(
            cx + reach[a] * math.cos(a * 2 * math.pi / rays),
            cy + reach[a] * math.sin(a * 2 * math.pi / rays),
          ),
    ];
    // Most rays must find the ring: else this is not a framed opening.
    if (points.length < rays * 0.6) return null;
    final circle = enclosingCircle(points);
    final d = 2 * circle.radius / w;
    if (d < 0.2 || d > 1) return null;
    return (
      centre: Offset(circle.centre.dx / w, circle.centre.dy / h),
      diameter: d,
    );
  }

  /// The smallest circle around [points] (≈ 0.1 % of their spread): the
  /// centre's search narrows around the best one so far.
  @visibleForTesting
  static ({Offset centre, double radius}) enclosingCircle(List<Offset> points) {
    double radiusAt(Offset c) {
      var r = 0.0;
      for (final p in points) {
        r = math.max(r, (p - c).distance);
      }
      return r;
    }

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final p in points) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    var best = Offset((left + right) / 2, (top + bottom) / 2);
    var bestR = radiusAt(best);
    var span = math.max(right - left, bottom - top) / 4;
    while (span > 0.001 * math.max(1, bestR)) {
      final around = best;
      for (var i = -4; i <= 4; i++) {
        for (var j = -4; j <= 4; j++) {
          final c = around + Offset(i * span / 4, j * span / 4);
          final r = radiusAt(c);
          if (r < bestR) {
            bestR = r;
            best = c;
          }
        }
      }
      span /= 2;
    }
    return (centre: best, radius: bestR);
  }

  /// The part of the canvas the art actually covers (alpha ≥ 40 in any
  /// sampled frame), as fractions; null when it cannot be read. Measured
  /// once per clip — badges are sized by what shows, not by the canvas.
  Future<Rect?> visibleBounds() => _bounds[this] ??= _measureBounds();

  static final _bounds = Expando<Future<Rect?>>();

  Future<Rect?> _measureBounds() async {
    var l = 1 << 30;
    var t = 1 << 30;
    var r = -1;
    var b = -1;
    var w = 1;
    var h = 1;
    final step = math.max(1, frames.length ~/ 6);
    for (var f = 0; f < frames.length; f += step) {
      final image = frames[f];
      final data = await image.toByteData();
      if (data == null) return null;
      w = image.width;
      h = image.height;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (data.getUint8((y * w + x) * 4 + 3) >= 40) {
            if (x < l) l = x;
            if (x > r) r = x;
            if (y < t) t = y;
            if (y > b) b = y;
          }
        }
      }
    }
    if (r < 0) return null;
    return Rect.fromLTRB(l / w, t / h, (r + 1) / w, (b + 1) / h);
  }

  /// The frame shown [elapsed] after the start (looping).
  int frameAt(Duration elapsed, {bool loop = true}) {
    final i = (elapsed.inMicroseconds * math.max(1, fps) / 1e6).floor();
    if (!loop) return math.min(i, frames.length - 1);
    return i % frames.length;
  }
}

/// The shared, bounded cache of [VipSvgaClip]s (url × size bucket).
abstract final class VipSvgaCache {
  /// Fetches the file's bytes (the gift art cache); tests replace it.
  static Future<Uint8List> Function(String url) fetch = _fetch;

  static Future<Uint8List> _fetch(String url) {
    if (!GiftArtCache.allowed(url)) {
      return Future.error(ArgumentError.value(url, 'url', 'not allowed'));
    }
    return GiftArtCache.instance.load(url);
  }

  /// Total pixels of the frames kept (≈ 4 bytes each): 24 M ≈ 96 MB.
  static int maxPixels = 24 * 1000 * 1000;

  static final _clips = <String, Future<VipSvgaClip?>>{};
  static final _pixels = <String, int>{};

  /// The longest side a frame is drawn at, for a box [maxSide] device
  /// pixels across: the next power of two from 64 to 1024.
  static int bucket(double maxSide) {
    var side = 64;
    while (side < maxSide && side < 1024) {
      side *= 2;
    }
    return side;
  }

  /// [url]'s clip for frames [maxSide] device pixels at most (null when it
  /// cannot be read; tried again on the next call).
  static Future<VipSvgaClip?> load(String url, {required double maxSide}) {
    final key = '${bucket(maxSide)}|$url';
    final hit = _clips.remove(key);
    if (hit != null) {
      _clips[key] = hit; // most recently used last.
      return hit;
    }
    final future = _decode(url, bucket(maxSide)).then((clip) {
      if (clip == null) {
        unawaited(_clips.remove(key));
        return null;
      }
      _pixels[key] = clip.frames.fold(0, (sum, f) => sum + f.width * f.height);
      _evict(keep: key);
      return clip;
    });
    _clips[key] = future;
    return future;
  }

  static void _evict({required String keep}) {
    var total = _pixels.values.fold(0, (a, b) => a + b);
    while (total > maxPixels) {
      final oldest = _clips.keys.firstWhere(
        (k) => k != keep && _pixels.containsKey(k),
        orElse: () => '',
      );
      if (oldest.isEmpty) return;
      total -= _pixels.remove(oldest) ?? 0;
      // (Frames still painted elsewhere stay valid until that widget goes:
      // images are only dropped by the cache, not disposed under a painter.)
      unawaited(_clips.remove(oldest));
    }
  }

  /// Forgets everything (tests).
  @visibleForTesting
  static void clear() {
    _clips.clear();
    _pixels.clear();
  }

  static Future<VipSvgaClip?> _decode(String url, int side) async {
    try {
      final bytes = await fetch(url);
      final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
      try {
        return render(movie, side);
      } finally {
        movie.dispose();
      }
    } on Object catch (e) {
      debugPrint('VipSvgaCache($url): $e');
      return null;
    }
  }

  /// Draws every frame of [movie] with its longest side [side] pixels.
  static VipSvgaClip render(MovieEntity movie, int side) {
    final box = Size(movie.params.viewBoxWidth, movie.params.viewBoxHeight);
    final k = side / math.max(1, math.max(box.width, box.height));
    final w = math.max(1, (box.width * k).round());
    final h = math.max(1, (box.height * k).round());
    final frames = <ui.Image>[];
    for (var i = 0; i < math.max(1, movie.params.frames); i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(k);
      drawFrame(canvas, movie, i);
      final picture = recorder.endRecording();
      frames.add(picture.toImageSync(w, h));
      picture.dispose();
    }
    return VipSvgaClip(
      viewBox: box,
      fps: movie.params.fps <= 0 ? 20 : movie.params.fps,
      frames: frames,
      scale: k,
    );
  }

  /// Frame [index] of [movie]'s bitmaps (with their alpha and transform) on
  /// [canvas], in the SVGA's own units.
  static void drawFrame(Canvas canvas, MovieEntity movie, int index) {
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
    for (final sprite in movie.sprites) {
      if (index >= sprite.frames.length) continue;
      final bitmap = movie.bitmapCache[sprite.imageKey];
      if (bitmap == null) continue;
      final frame = sprite.frames[index];
      final alpha = frame.hasAlpha() ? frame.alpha : 1.0;
      if (alpha <= 0 || !frame.hasLayout()) continue;
      canvas.save();
      if (frame.hasTransform()) {
        final t = frame.transform;
        canvas.transform(
          Float64List.fromList([
            t.a, t.b, 0, 0, //
            t.c, t.d, 0, 0,
            0, 0, 1, 0,
            t.tx, t.ty, 0, 1,
          ]),
        );
      }
      paint.color = Color.fromRGBO(0, 0, 0, alpha.clamp(0, 1));
      canvas
        ..drawImageRect(
          bitmap,
          Rect.fromLTWH(
            0,
            0,
            bitmap.width.toDouble(),
            bitmap.height.toDouble(),
          ),
          Rect.fromLTWH(0, 0, frame.layout.width, frame.layout.height),
          paint,
        )
        ..restore();
    }
  }
}

/// How a clip is fitted into its box: a [BoxFit] (badge, frame, banner, car,
/// wave) or [VipSvgaNine] (the bubble and the card, stretched to their box).
typedef VipSvgaPlacement = ({BoxFit? fit, VipSvgaNine? nine});

/// D258: the 9-slice of a stretchable SVGA (a chat bubble, a person card):
/// [body] is the part of the canvas that covers the widget's box (the rest —
/// ornaments — overflows it); [slice] the stretchable middle. Both are
/// fractions of the SVGA's canvas, so a template exported at another size
/// still fits. [scaleBy] picks the scale from the box: the bubble keeps the
/// art's height to the box's height (it stretches sideways), the card its
/// width (it stretches downwards).
@immutable
class VipSvgaNine {
  const new({
    required this.body,
    required this.slice,
    required this.scaleBy,
    this.maxHeight,
    this.template,
  });

  final Rect body;
  final Rect slice;
  final Axis scaleBy;

  /// D265: the tallest [body] is drawn at (screen units, [Axis.vertical]
  /// only): a taller box keeps that scale and stretches the slice
  /// downwards, so a message of several lines keeps the frame's edge and
  /// ornaments at their one-line size (they grew with the box before).
  final double? maxHeight;

  /// The template's canvas (its proportions, for [minWidth]).
  final Size? template;

  /// D265: the narrowest box the art's fixed parts fit (the ornaments'
  /// corner and the end), at [maxHeight]: a one-letter message is never
  /// narrower than its frame (the art overflowed its box before).
  double get minWidth {
    final t = template;
    final h = maxHeight;
    if (t == null || h == null) return 0;
    final b = _abs(body, t);
    final c = _abs(slice, t);
    return (b.width - c.width) * h / b.height;
  }

  /// The owner's chat bubble template (`svip_text_bubble`, 990 × 720): the
  /// frame's edge 150,127 – 819,584; the ornaments overflow up and left; it
  /// stretches between x 620 and 760 (right of the ornaments) and, D265,
  /// between y 340 and 380 (straight edges; the rounded bottom corners
  /// smeared when 530 – 560 stretched).
  static const bubble = VipSvgaNine(
    body: Rect.fromLTRB(150 / 990, 127 / 720, 819 / 990, 584 / 720),
    slice: Rect.fromLTRB(620 / 990, 340 / 720, 760 / 990, 380 / 720),
    scaleBy: Axis.vertical,
    // One text line of the chats (≈ 28–31 pt with its padding).
    maxHeight: 32,
    template: Size(990, 720),
  );

  /// The owner's person card template (`svip_box`, 720 × 1280): the card
  /// from y 380 (its top edge; the crest rises above it) to 1262; it
  /// stretches between y 700 and 1100.
  static const card = VipSvgaNine(
    body: Rect.fromLTRB(0, 380 / 1280, 1, 1262 / 1280),
    slice: Rect.fromLTRB(200 / 720, 700 / 1280, 520 / 720, 1100 / 1280),
    scaleBy: Axis.horizontal,
  );

  static Rect _abs(Rect f, Size box) => Rect.fromLTRB(
    f.left * box.width,
    f.top * box.height,
    f.right * box.width,
    f.bottom * box.height,
  );

  /// The scale for a box of [size] (screen units per SVGA unit).
  double scaleFor(Size size, Size viewBox) {
    final b = _abs(body, viewBox);
    return scaleBy == Axis.vertical
        ? math.min(size.height, maxHeight ?? double.infinity) / b.height
        : size.width / b.width;
  }

  /// Where the whole canvas lands for a box of [size] (it overflows).
  Rect outerFor(Size size, Size viewBox) {
    final s = scaleFor(size, viewBox);
    final b = _abs(body, viewBox);
    return Rect.fromLTRB(
      -b.left * s,
      -b.top * s,
      size.width + (viewBox.width - b.right) * s,
      size.height + (viewBox.height - b.bottom) * s,
    );
  }

  void paint(Canvas canvas, Size size, VipSvgaClip clip, ui.Image image) {
    final s = scaleFor(size, clip.viewBox);
    if (s <= 0 || !s.isFinite) return;
    final outer = outerFor(size, clip.viewBox);
    final k = clip.scale;
    // In image pixels: the corners keep their size, the slice stretches.
    final c = _abs(slice, clip.viewBox);
    final center = Rect.fromLTRB(
      c.left * k,
      c.top * k,
      c.right * k,
      c.bottom * k,
    );
    canvas
      ..save()
      ..translate(outer.left, outer.top)
      ..scale(s / k);
    final dst = Rect.fromLTWH(
      0,
      0,
      math.max(image.width - center.width, outer.width * k / s),
      math.max(image.height - center.height, outer.height * k / s),
    );
    canvas
      ..drawImageNine(
        image,
        center,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
  }
}

/// Plays [url]'s SVGA (shared clip, shared clock) in its box: fitted
/// ([fit]) or 9-sliced ([nine]). [still] shows while it
/// loads, when it cannot be read, in tests and with reduced motion (the
/// first frame then, when no still). [once]: plays to the end, then
/// [onDone] (also called when it cannot play).
class VipSvga extends StatefulWidget {
  const new({
    required this.url,
    super.key,
    this.fit = BoxFit.contain,
    this.nine,
    this.still,
    this.once = false,
    this.onDone,
    this.resolution = 1,
  });

  final String url;

  /// The frames' sharpness: 1 draws them at the device's pixels; less keeps
  /// a big art (the card) lighter in memory.
  final double resolution;
  final BoxFit fit;
  final VipSvgaNine? nine;

  /// Shown until the clip is ready, and instead of it when it cannot play.
  final Widget? still;
  final bool once;
  final VoidCallback? onDone;

  /// Widget tests turn playing off (the still shows; see VipAnimatedArt).
  static bool enabled = true;

  /// The shared clock every looping clip follows (all in step).
  static final Stopwatch _epoch = Stopwatch()..start();

  @override
  State<VipSvga> createState() => _VipSvgaState();
}

class _VipSvgaState extends State<VipSvga> with SingleTickerProviderStateMixin {
  VipSvgaClip? _clip;
  Ticker? _ticker;
  int _frame = 0;
  Duration _start = Duration.zero;
  bool _done = false;
  bool _still = false;
  double? _side;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = !VipSvga.enabled || MediaQuery.disableAnimationsOf(context);
    if (_still && widget.once) _finishSoon();
  }

  @override
  void didUpdateWidget(VipSvga old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _ticker?.stop();
      _clip = null;
      _side = null;
    }
  }

  void _finishSoon() {
    if (_done) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone?.call();
    });
  }

  void _load(double side) {
    if (_side != null && _side! >= side) return;
    _side = side;
    final url = widget.url;
    unawaited(
      VipSvgaCache.load(url, maxSide: side).then((clip) {
        if (!mounted || widget.url != url) return;
        if (clip == null) {
          if (widget.once) _finishSoon();
          return;
        }
        setState(() {
          _clip = clip;
          _start = VipSvga._epoch.elapsed;
        });
        if (_still) {
          if (widget.once) _finishSoon();
          return;
        }
        (_ticker ??= createTicker(_tick)).start();
      }),
    );
  }

  void _tick(Duration _) {
    final clip = _clip;
    if (clip == null) return;
    final now = VipSvga._epoch.elapsed;
    final int frame;
    if (widget.once) {
      final elapsed = now - _start;
      if (elapsed >= clip.duration) {
        _ticker?.stop();
        _finishSoon();
        return;
      }
      frame = clip.frameAt(elapsed, loop: false);
    } else {
      frame = clip.frameAt(now);
    }
    if (frame != _frame) setState(() => _frame = frame);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
      final w = box.maxWidth.isFinite ? box.maxWidth : 0.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : 0.0;
      if (_still && !widget.once && widget.still != null) {
        return widget.still!;
      }
      if (!_still || widget.still == null) {
        final nine = widget.nine;
        // A 9-sliced art is drawn bigger than its box (its ornaments): about
        // twice the side it scales by.
        final side = nine == null
            ? math.max(w, h)
            : 2.2 *
                  (nine.scaleBy == Axis.vertical
                      ? math.min(h, nine.maxHeight ?? h)
                      : w);
        _load(side * dpr * widget.resolution);
      }
      final clip = _clip;
      if (clip == null || (_still && widget.once)) {
        return widget.still ?? const SizedBox.shrink();
      }
      return CustomPaint(
        size: Size(w, h),
        painter: _ClipPainter(
          clip: clip,
          frame: _frame.clamp(0, clip.frames.length - 1),
          fit: widget.fit,
          nine: widget.nine,
        ),
      );
    },
  );
}

class _ClipPainter extends CustomPainter {
  new({
    required this.clip,
    required this.frame,
    required this.fit,
    required this.nine,
  });

  final VipSvgaClip clip;
  final int frame;
  final BoxFit fit;
  final VipSvgaNine? nine;

  @override
  void paint(Canvas canvas, Size size) {
    final image = clip.frames[frame];
    final nine = this.nine;
    if (nine != null) {
      nine.paint(canvas, size, clip, image);
      return;
    }
    final src = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(fit, src, size);
    final dst = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final from = Alignment.center.inscribe(fitted.source, Offset.zero & src);
    canvas.drawImageRect(
      image,
      from,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ClipPainter old) =>
      old.clip != clip || old.frame != frame || old.fit != fit;
}
