import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:kabso_live/core/svga/svga_engine.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_effect_sound.dart';
import 'package:material_ui/material_ui.dart';

/// D258: the VIP art's SVGA engine. Every perk's SVGA (badge, frame, bubble,
/// card, banner, car, mic wave) goes through one shared cache: a file is
/// downloaded once (the gift art cache, kept on the device), decoded once,
/// and each frame is drawn ONCE into a small image at the size it is shown
/// (bucketed), after which the full-size bitmaps are released. A 3.7 MB
/// badge in fifty chat lines is then one set of small frames, and every
/// line shows the same frame of one shared clock (no controller per line).
///
/// D272 (owner: the entry car stutters, freezes and is silent): the file is
/// read (inflated, parsed) on another isolate ([SvgaDoc.read]); its
/// pictures are decoded at the size they are drawn, never bigger; the
/// frames are drawn without blocking the UI; a clip too big to keep as
/// frames ([VipSvgaCache.clipPixels] — the owner's 75-frame 563 × 1000
/// peacock car would take 177 MB) is drawn [live] from a short window of
/// decoded pictures instead; and the SVGA's own sound ([sounds]) plays with
/// it where the widget asks for it ([VipSvga.sound]).
class VipSvgaClip {
  const new({
    required this.viewBox,
    required this.fps,
    required this.frames,
    required this.scale,
    this.sounds = const [],
    this.live,
    this.frameTotal,
    this.area,
  });

  /// The SVGA's canvas, in its own units.
  final Size viewBox;

  /// D280: what the clip draws inside its canvas (canvas units; null:
  /// unknown), [SvgaDoc.area].
  final Rect? area;

  /// D280: the canvas without the rows the clip never draws below its art
  /// (canvas units, from the top).
  Size get trimmedBox {
    final bottom = area?.bottom;
    if (bottom == null || bottom <= 0 || bottom >= viewBox.height) {
      return viewBox;
    }
    return Size(viewBox.width, bottom);
  }

  final int fps;

  /// Each frame drawn at [scale] × the canvas (empty when [live]).
  final List<ui.Image> frames;
  final double scale;

  /// D272: the SVGA's own sounds (its `audios`), with their timing.
  final List<SvgaSound> sounds;

  /// D272: a big clip drawn as it plays (no frames kept).
  final SvgaLive? live;

  /// The frame count when [frames] does not hold them ([live]).
  final int? frameTotal;

  int get frameCount => frameTotal ?? frames.length;

  Duration get duration =>
      Duration(milliseconds: (frameCount * 1000 / math.max(1, fps)).round());

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
    final n = math.max(1, frameCount);
    final i = (elapsed.inMicroseconds * math.max(1, fps) / 1e6).floor();
    if (!loop) return math.min(i, n - 1);
    return i % n;
  }
}

/// D272: the one VIP SVGA sound playing (an entrance's car or banner): a
/// new one stops the one before, so two entrances never sound together.
abstract final class VipSvgaAudio {
  static GiftEffectSound? _current;

  /// The sound playing now (tests).
  @visibleForTesting
  static GiftEffectSound? get current => _current;

  /// Starts [sounds] (stopping the one playing); returns its handle.
  static GiftEffectSound start(List<SvgaSound> sounds) {
    final previous = _current;
    if (previous != null) unawaited(previous.stop());
    final sound = GiftEffectSound.fromSvga(sounds);
    _current = sound;
    return sound;
  }

  /// Stops [sound] (when it is still the one playing, it no longer is).
  static void stop(GiftEffectSound? sound) {
    if (sound == null) return;
    if (identical(_current, sound)) _current = null;
    unawaited(sound.stop());
  }
}

/// The shared, bounded cache of [VipSvgaClip]s (url × size bucket).
abstract final class VipSvgaCache {
  /// Fetches the file's bytes (the gift art cache); tests replace it.
  /// D272b: the shared engine's ([SvgaDocs.fetch]).
  static Future<Uint8List> Function(String url) get fetch => SvgaDocs.fetch;
  static set fetch(Future<Uint8List> Function(String url) f) =>
      SvgaDocs.fetch = f;

  /// Total pixels of the frames kept (≈ 4 bytes each): 24 M ≈ 96 MB.
  static int maxPixels = 24 * 1000 * 1000;

  /// D272: the most one clip keeps as frames (12 M ≈ 48 MB); a bigger one
  /// (the owner's 75-frame peacock car: 44 M at the car's size) is drawn
  /// [VipSvgaClip.live] instead of evicting everything else.
  static int clipPixels = 12 * 1000 * 1000;

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

  /// D272: reads [url] ahead (downloads it and parses it on another
  /// isolate) so it plays at once when it is shown (a VIP's entrance as
  /// their join arrives). Never throws.
  static Future<void> warm(String url) => SvgaDocs.warm(url);

  /// [url]'s clip for frames [maxSide] device pixels at most (null when it
  /// cannot be read; tried again on the next call). [live]: a clip too big
  /// to keep as frames may be drawn as it plays (else it is kept smaller).
  static Future<VipSvgaClip?> load(
    String url, {
    required double maxSide,
    bool live = true,
  }) {
    final key = '${bucket(maxSide)}|${live ? '' : 'f|'}$url';
    final hit = _clips.remove(key);
    if (hit != null) {
      _clips[key] = hit; // most recently used last.
      return hit;
    }
    final future = _decode(url, bucket(maxSide), live: live).then((clip) {
      if (clip == null) {
        unawaited(_clips.remove(key));
        return null;
      }
      _pixels[key] = clip.live != null
          ? clip.live!.doc.encodedBytes ~/ 4
          : clip.frames.fold(0, (sum, f) => sum + f.width * f.height);
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
    SvgaDocs.clear();
  }

  static Future<VipSvgaClip?> _decode(
    String url,
    int side, {
    required bool live,
  }) async {
    final doc = await SvgaDocs.doc(url);
    if (doc == null) return null;
    try {
      return await render(doc, side, live: live);
    } on Object catch (e) {
      debugPrint('VipSvgaCache($url): $e');
      return null;
    }
  }

  /// [doc]'s clip with its longest side [side] pixels: every frame drawn
  /// once (one at a time, each picture decoded at the size it is drawn,
  /// then released), or — when the frames would take more than
  /// [clipPixels] — drawn [live] as it plays (or, not [live], at a smaller
  /// side that fits).
  static Future<VipSvgaClip> render(
    SvgaDoc doc,
    int side, {
    bool live = true,
  }) async {
    final box = doc.viewBox;
    var s = side;
    double scaleOf(int s) => s / math.max(1, math.max(box.width, box.height));
    int pixelsOf(int s) {
      final k = scaleOf(s);
      final w = math.max(1, (box.width * k).round());
      final h = math.max(1, (box.height * k).round());
      return doc.frameCount * w * h;
    }

    if (pixelsOf(s) > clipPixels) {
      if (live) {
        return VipSvgaClip(
          viewBox: box,
          fps: doc.fps,
          frames: const [],
          scale: scaleOf(s),
          sounds: doc.sounds,
          live: SvgaLive(doc, scaleOf(s)),
          frameTotal: doc.frameCount,
          area: doc.area,
        );
      }
      while (s > 64 && pixelsOf(s) > clipPixels) {
        s ~/= 2;
      }
    }
    final k = scaleOf(s);
    final w = math.max(1, (box.width * k).round());
    final h = math.max(1, (box.height * k).round());
    final pictures = <String, ui.Image>{};
    for (final key in doc.images.keys) {
      if (!doc.drawn.containsKey(key)) continue; // never drawn.
      final image = await doc.decode(key, k);
      if (image != null) pictures[key] = image;
    }
    final frames = <ui.Image>[];
    try {
      for (var i = 0; i < doc.frameCount; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(k);
        doc.drawFrame(canvas, i, pictures);
        final picture = recorder.endRecording();
        try {
          // Drawn by the engine, one frame at a time (the UI and the
          // raster thread are never held for the whole clip).
          frames.add(await picture.toImage(w, h));
        } finally {
          picture.dispose();
        }
      }
    } finally {
      for (final image in pictures.values) {
        image.dispose();
      }
    }
    return VipSvgaClip(
      viewBox: box,
      fps: doc.fps,
      frames: frames,
      scale: k,
      sounds: doc.sounds,
      area: doc.area,
    );
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
///
/// D272: [onStarted] runs when it starts playing (with the clip's length):
/// a big clip starts only once its first second is decoded. [sound]: the
/// SVGA's own sound plays with it (an entrance's car or banner; never the
/// badges, frames and bubbles of the chat) — only while it moves (not with
/// reduced motion, where the still shows silently), only in the
/// foreground, one at a time ([VipSvgaAudio]); it stops when the clip ends,
/// is removed, or [sound] turns off.
class VipSvga extends StatefulWidget {
  const new({
    required this.url,
    super.key,
    this.fit = BoxFit.contain,
    this.nine,
    this.still,
    this.once = false,
    this.onDone,
    this.onStarted,
    this.sound = false,
    this.resolution = 1,
    this.alignment = Alignment.center,
    this.trimBottom = false,
    this.fitFor,
  });

  final String url;

  /// D331: the fit for the clip's own canvas (its view box), in place of
  /// [fit] once it is read (the entry car: a portrait one covers the screen).
  final BoxFit Function(Size canvas)? fitFor;

  /// D280: where the fitted clip sits in its box (the entry car: at the
  /// bottom).
  final Alignment alignment;

  /// D280: the rows the clip never draws below its art are left out (so a
  /// bottom-aligned car touches the box's bottom).
  final bool trimBottom;

  /// The frames' sharpness: 1 draws them at the device's pixels; less keeps
  /// a big art (the card) lighter in memory.
  final double resolution;
  final BoxFit fit;
  final VipSvgaNine? nine;

  /// Shown until the clip is ready, and instead of it when it cannot play.
  final Widget? still;
  final bool once;
  final VoidCallback? onDone;
  final ValueChanged<Duration>? onStarted;
  final bool sound;

  /// Widget tests turn playing off (the still shows; see VipAnimatedArt).
  static bool enabled = true;

  /// The shared clock every looping clip follows (all in step).
  static final Stopwatch _epoch = Stopwatch()..start();

  /// The shared clock's time (tests: the fake clock).
  @visibleForTesting
  static Duration Function() clock = () => _epoch.elapsed;

  @override
  State<VipSvga> createState() => _VipSvgaState();
}

class _VipSvgaState extends State<VipSvga> with SingleTickerProviderStateMixin {
  VipSvgaClip? _clip;
  SvgaReader? _reader;
  GiftEffectSound? _sound;
  AppLifecycleListener? _lifecycle;
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
    if (_still) _stopSound();
    if (_still && widget.once) _finishSoon();
  }

  @override
  void didUpdateWidget(VipSvga old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _ticker?.stop();
      _stopSound();
      _reader?.dispose();
      _reader = null;
      _clip = null;
      _side = null;
    } else if (old.sound && !widget.sound) {
      _stopSound();
    }
  }

  void _finishSoon() {
    if (_done) return;
    _done = true;
    _stopSound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone?.call();
    });
  }

  void _load(double side) {
    if (_side != null && _side! >= side) return;
    _side = side;
    final url = widget.url;
    unawaited(
      VipSvgaCache.load(url, maxSide: side, live: widget.nine == null).then((
        clip,
      ) async {
        if (!mounted || widget.url != url) return;
        if (clip == null) {
          if (widget.once) _finishSoon();
          return;
        }
        if (identical(clip, _clip)) return;
        final live = clip.live;
        SvgaReader? reader;
        if (live != null && !_still) {
          // A big clip starts once its first second is decoded.
          reader = SvgaReader(live);
          final from = widget.once ? 0 : clip.frameAt(VipSvga.clock());
          await reader.want(from, loop: !widget.once);
          if (!mounted || widget.url != url || _done) {
            reader.dispose();
            return;
          }
          _frame = from;
        }
        _reader?.dispose();
        _reader = reader;
        setState(() {
          _clip = clip;
          _start = VipSvga.clock();
        });
        if (_still) {
          if (widget.once) _finishSoon();
          return;
        }
        // A larger size loads again while the first plays (the text grew):
        // the running ticker keeps going (D269: was started twice).
        final ticker = _ticker ??= createTicker(_tick);
        if (!ticker.isActive) {
          widget.onStarted?.call(clip.duration);
          _startSound(clip);
          ticker.start();
        }
      }),
    );
  }

  void _startSound(VipSvgaClip clip) {
    if (!widget.sound || clip.sounds.isEmpty || _sound != null) return;
    final sound = VipSvgaAudio.start(clip.sounds);
    _sound = sound;
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (state) {
        // Never in the background (the picture may go on).
        if (state != AppLifecycleState.resumed) _stopSound();
      },
    );
    sound.onFrame(widget.once ? 0 : _frame);
  }

  void _stopSound() {
    VipSvgaAudio.stop(_sound);
    _sound = null;
  }

  void _tick(Duration _) {
    final clip = _clip;
    if (clip == null) return;
    final now = VipSvga.clock();
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
    // The sound follows the clock (a late picture never holds it).
    _sound?.onFrame(frame);
    final reader = _reader;
    if (reader != null) {
      unawaited(reader.want(frame, loop: !widget.once));
      // A picture not decoded yet: the last frame stays a moment.
      if (!reader.ready(frame)) return;
    }
    if (frame != _frame) setState(() => _frame = frame);
  }

  @override
  void dispose() {
    _stopSound();
    _lifecycle?.dispose();
    _reader?.dispose();
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
      if (clip == null ||
          (_still && widget.once) ||
          (clip.live != null && _reader == null)) {
        return widget.still ?? const SizedBox.shrink();
      }
      return CustomPaint(
        size: Size(w, h),
        painter: _ClipPainter(
          clip: clip,
          frame: _frame.clamp(0, math.max(0, clip.frameCount - 1)),
          fit: widget.fitFor?.call(clip.viewBox) ?? widget.fit,
          nine: widget.nine,
          reader: _reader,
          alignment: widget.alignment,
          trimBottom: widget.trimBottom,
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
    this.reader,
    this.alignment = Alignment.center,
    this.trimBottom = false,
  });

  final Alignment alignment;
  final bool trimBottom;

  final VipSvgaClip clip;
  final int frame;
  final BoxFit fit;
  final VipSvgaNine? nine;
  final SvgaReader? reader;

  @override
  void paint(Canvas canvas, Size size) {
    final reader = this.reader;
    final live = clip.live;
    if (live != null && reader != null) {
      // D272: drawn now from the decoded window, fitted like a frame.
      final box = trimBottom ? clip.trimmedBox : clip.viewBox;
      final fitted = applyBoxFit(fit, box, size);
      final dst = alignment.inscribe(fitted.destination, Offset.zero & size);
      final from = alignment.inscribe(fitted.source, Offset.zero & box);
      canvas
        ..save()
        ..clipRect(dst)
        ..translate(dst.left, dst.top)
        ..scale(dst.width / from.width, dst.height / from.height)
        ..translate(-from.left, -from.top);
      live.doc.drawFrame(canvas, frame, reader.pictures);
      canvas.restore();
      return;
    }
    if (clip.frames.isEmpty) return;
    final image = clip.frames[frame];
    final nine = this.nine;
    if (nine != null) {
      nine.paint(canvas, size, clip, image);
      return;
    }
    final trimmed = trimBottom ? clip.trimmedBox : clip.viewBox;
    final src = Size(
      image.width.toDouble(),
      clip.viewBox.height > 0
          ? image.height * trimmed.height / clip.viewBox.height
          : image.height.toDouble(),
    );
    final fitted = applyBoxFit(fit, src, size);
    final dst = alignment.inscribe(fitted.destination, Offset.zero & size);
    final from = alignment.inscribe(fitted.source, Offset.zero & src);
    canvas.drawImageRect(
      image,
      from,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ClipPainter old) =>
      old.clip != clip ||
      old.frame != frame ||
      old.fit != fit ||
      old.reader != reader ||
      old.alignment != alignment ||
      old.trimBottom != trimBottom;
}
