import 'dart:async';
import 'dart:io' show ZLibCodec;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';

// D272 / D272b: the app's one SVGA engine. Every SVGA (the VIP perks, the
// gifts' full-screen effects, the PK battle emoji, the profile headers) is
// read here: fetched once (the gift art cache, or the app's bundle), read
// on another isolate into plain data ([SvgaDoc.read]), its pictures decoded
// by the engine at the size they are drawn (never bigger). A big clip is
// drawn as it plays from a short window of decoded pictures ([SvgaReader]);
// a small one keeps its pictures ([SvgaLive.resident]). The few files with
// vector shapes or clip paths go to the package's player through
// [SvgaDoc.toMovie] (same reading, same decoding).

/// D272: one sound of an SVGA (`MovieEntity.audios`): [bytes] (MP3) start
/// at [startFrame] (from [startTime] ms into the sound) until [endFrame];
/// [totalTime] is the sound's length (ms; 0 when the file does not say).
@immutable
class SvgaSound {
  const new({
    required this.key,
    required this.startFrame,
    required this.endFrame,
    required this.bytes,
    this.startTime = 0,
    this.totalTime = 0,
  });

  final String key;
  final int startFrame;
  final int endFrame;
  final int startTime;
  final int totalTime;
  final Uint8List bytes;
}

/// D272: an SVGA read into plain data (on another isolate: [read]) — its
/// canvas, its pictures still encoded, each sprite's frames and its
/// sounds. Nothing here is decoded or drawn yet.
@immutable
class SvgaDoc {
  const new({
    required this.viewBox,
    required this.fps,
    required this.frameCount,
    required this.images,
    required this.sprites,
    required this.frameKeys,
    required this.drawn,
    required this.sounds,
    this.bounds,
    this.vector = false,
    this.skeleton,
  });

  /// Reads [bytes] here (the isolate's work; tests).
  factory parse(Uint8List bytes) {
    final movie = MovieEntity.fromBuffer(ZLibCodec().decode(bytes));
    final frameCount = math.max(1, movie.params.frames);
    final audioKeys = {for (final a in movie.audios) a.audioKey};
    final images = <String, Uint8List>{};
    final mp3 = <String, Uint8List>{};
    movie.images.forEach((key, value) {
      final data = value is Uint8List ? value : Uint8List.fromList(value);
      final id3 =
          data.length > 3 &&
          data[0] == 0x49 &&
          data[1] == 0x44 &&
          data[2] == 0x33;
      (audioKeys.contains(key) || id3 ? mp3 : images)[key] = data;
    });
    final sprites = <SvgaSprite>[];
    final frameKeys = [for (var i = 0; i < frameCount; i++) <String>[]];
    final drawn = <String, Size>{};
    final box = Rect.fromLTWH(
      0,
      0,
      movie.params.viewBoxWidth,
      movie.params.viewBoxHeight,
    );
    Rect? area;
    var vector = false;
    for (final sprite in movie.sprites) {
      final key = sprite.imageKey;
      for (final f in sprite.frames) {
        if (f.shapes.isNotEmpty || f.clipPath.isNotEmpty) vector = true;
        // What it covers (the player draws it at 0, 0, layout under the
        // transform): the drawn area of the whole clip — every sprite with
        // a key, its picture or shapes (D145c).
        final alpha = f.hasAlpha() ? f.alpha : 1.0;
        final lw = f.layout.width;
        final lh = f.layout.height;
        if (key.isEmpty || alpha <= 0 || lw <= 0 || lh <= 0) continue;
        final t = f.hasTransform() ? f.transform : null;
        final a = t?.a ?? 1.0;
        final b = t?.b ?? 0.0;
        final c = t?.c ?? 0.0;
        final d = t?.d ?? 1.0;
        final tx = t?.tx ?? 0.0;
        final ty = t?.ty ?? 0.0;
        final xs = [0.0, a * lw, c * lh, a * lw + c * lh];
        final ys = [0.0, b * lw, d * lh, b * lw + d * lh];
        final r = Rect.fromLTRB(
          tx + xs.reduce(math.min),
          ty + ys.reduce(math.min),
          tx + xs.reduce(math.max),
          ty + ys.reduce(math.max),
        );
        area = area == null ? r : area.expandToInclude(r);
      }
      if (!images.containsKey(key)) continue;
      final n = math.min(sprite.frames.length, frameCount);
      final data = Float32List(n * SvgaSprite.stride);
      var w = 0.0;
      var h = 0.0;
      for (var i = 0; i < n; i++) {
        final f = sprite.frames[i];
        final alpha = f.hasAlpha() ? f.alpha : 1.0;
        if (alpha <= 0 || !f.hasLayout()) continue;
        final t = f.hasTransform() ? f.transform : null;
        final a = t?.a ?? 1.0;
        final b = t?.b ?? 0.0;
        final c = t?.c ?? 0.0;
        final d = t?.d ?? 1.0;
        data.setAll(i * SvgaSprite.stride, [
          alpha.clamp(0, 1).toDouble(),
          f.layout.width,
          f.layout.height,
          a,
          b,
          c,
          d,
          t?.tx ?? 0.0,
          t?.ty ?? 0.0,
        ]);
        frameKeys[i].add(key);
        w = math.max(w, f.layout.width * math.sqrt(a * a + b * b));
        h = math.max(h, f.layout.height * math.sqrt(c * c + d * d));
      }
      sprites.add(SvgaSprite(imageKey: key, frames: data));
      final was = drawn[key];
      drawn[key] = Size(
        math.max(w, was?.width ?? 0),
        math.max(h, was?.height ?? 0),
      );
    }
    final sounds = [
      for (final a in movie.audios)
        if (mp3[a.audioKey] case final bytes?)
          SvgaSound(
            key: a.audioKey,
            startFrame: a.startFrame,
            // A sound without its end lasts the whole clip.
            endFrame: a.endFrame > a.startFrame ? a.endFrame : frameCount,
            startTime: a.startTime,
            totalTime: a.totalTime,
            bytes: bytes,
          ),
    ];
    // The movie without its pictures (small): what the package's player
    // needs, rebuilt by [toMovie].
    movie.images.clear();
    final skeleton = Uint8List.fromList(movie.writeToBuffer());
    // A stray sprite far off the canvas does not shrink the movie: the
    // area stops at half a canvas beyond each edge (D145c).
    final limit = Rect.fromLTRB(
      -box.width / 2,
      -box.height / 2,
      box.width * 1.5,
      box.height * 1.5,
    );
    return SvgaDoc(
      bounds: box.isEmpty || area == null
          ? box
          : box.expandToInclude(area.intersect(limit)),
      vector: vector,
      skeleton: skeleton,
      viewBox: Size(movie.params.viewBoxWidth, movie.params.viewBoxHeight),
      fps: movie.params.fps <= 0 ? 20 : movie.params.fps,
      frameCount: frameCount,
      images: images,
      sprites: sprites,
      frameKeys: frameKeys,
      drawn: drawn,
      sounds: sounds,
    );
  }

  final Size viewBox;
  final int fps;
  final int frameCount;

  /// What the clip draws over all its frames (canvas units), at least the
  /// canvas: a gift is fitted by it (KGiftMovieFrame, D145c).
  final Rect? bounds;

  /// D272b: it has vector shapes or clip paths, which only the package's
  /// player draws ([toMovie]).
  final bool vector;

  /// The movie without its pictures (protobuf), for [toMovie].
  final Uint8List? skeleton;

  Duration get duration =>
      Duration(milliseconds: (frameCount * 1000 / math.max(1, fps)).round());

  /// The pictures, still encoded (PNG / JPEG / WebP), by key.
  final Map<String, Uint8List> images;
  final List<SvgaSprite> sprites;

  /// The pictures each frame draws.
  final List<List<String>> frameKeys;

  /// The biggest each picture is drawn (canvas units): it is never decoded
  /// bigger than that.
  final Map<String, Size> drawn;
  final List<SvgaSound> sounds;

  int get encodedBytes =>
      images.values.fold(0, (sum, b) => sum + b.length) +
      sounds.fold(0, (sum, s) => sum + s.bytes.length);

  /// Reads [bytes] (zlib SVGA 2.x) on another isolate.
  static Future<SvgaDoc> read(Uint8List bytes) => compute(SvgaDoc.parse, bytes);

  /// The size [key] is decoded at for a canvas drawn at [scale]: the
  /// biggest it is drawn, at most its own size ([natural]).
  ({int width, int height}) decodeSize(String key, Size natural, double scale) {
    final d = drawn[key] ?? natural;
    final k = math.min(
      1,
      math.max(
        d.width * scale / math.max(1, natural.width),
        d.height * scale / math.max(1, natural.height),
      ),
    );
    return (
      width: math.max(1, (natural.width * k).ceil()),
      height: math.max(1, (natural.height * k).ceil()),
    );
  }

  /// Picture [key]'s own size, read from its header (null when it cannot
  /// be read).
  Future<Size?> naturalSize(String key) async {
    final bytes = images[key];
    if (bytes == null) return null;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    } on Object {
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Decodes picture [key] for a canvas drawn at [scale] (by the engine,
  /// off the UI thread); null when it cannot be read.
  Future<ui.Image?> decode(String key, double scale) async {
    final bytes = images[key];
    if (bytes == null) return null;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = decodeSize(
        key,
        Size(descriptor.width.toDouble(), descriptor.height.toDouble()),
        scale,
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: size.width,
        targetHeight: size.height,
      );
      return (await codec.getNextFrame()).image;
    } on Object catch (e) {
      debugPrint('SvgaDoc($key): $e');
      return null;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Frame [index] on [canvas] (in the SVGA's own units) from the decoded
  /// [pictures] (a missing one is left out).
  void drawFrame(Canvas canvas, int index, Map<String, ui.Image> pictures) {
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
    for (final sprite in sprites) {
      final o = index * SvgaSprite.stride;
      if (o >= sprite.frames.length) continue;
      final f = sprite.frames;
      final alpha = f[o];
      if (alpha <= 0) continue;
      final bitmap = pictures[sprite.imageKey];
      if (bitmap == null) continue;
      canvas
        ..save()
        ..transform(
          Float64List.fromList([
            f[o + 3], f[o + 4], 0, 0, //
            f[o + 5], f[o + 6], 0, 0,
            0, 0, 1, 0,
            f[o + 7], f[o + 8], 0, 1,
          ]),
        );
      paint.color = Color.fromRGBO(0, 0, 0, alpha);
      canvas
        ..drawImageRect(
          bitmap,
          Rect.fromLTWH(
            0,
            0,
            bitmap.width.toDouble(),
            bitmap.height.toDouble(),
          ),
          Rect.fromLTWH(0, 0, f[o + 1], f[o + 2]),
          paint,
        )
        ..restore();
    }
  }
}

/// The tail of [SvgaDoc]: building the package's movie.
extension SvgaDocMovie on SvgaDoc {
  /// D272b: the package's [MovieEntity] for this file (for its player:
  /// vector shapes, clip paths), its pictures decoded for a canvas drawn
  /// at [scale] device pixels per unit (never bigger than they are), its
  /// sounds in `audiosData`. A new movie each call (the player releases
  /// it).
  Future<MovieEntity> toMovie(double scale) async {
    final movie = MovieEntity.fromBuffer(skeleton ?? Uint8List(0));
    // The parser's KEEP shapes (a frame that keeps the shapes before it).
    for (final sprite in movie.sprites) {
      List<ShapeEntity>? last;
      for (final frame in sprite.frames) {
        if (frame.shapes.isEmpty) continue;
        if (frame.shapes.first.type.name == 'KEEP' && last != null) {
          frame.shapes = last;
        } else {
          last = frame.shapes;
        }
      }
    }
    final keys = images.keys.toList();
    final decoded = await Future.wait([
      for (final key in keys) decode(key, scale),
    ]);
    for (var i = 0; i < keys.length; i++) {
      final image = decoded[i];
      if (image != null) movie.bitmapCache[keys[i]] = image;
    }
    for (final s in sounds) {
      movie.audiosData[s.key] = s.bytes;
    }
    return movie;
  }
}

/// One sprite of a [SvgaDoc]: per frame [stride] numbers — alpha (0:
/// not drawn), layout width and height, transform a b c d tx ty.
@immutable
class SvgaSprite {
  const new({required this.imageKey, required this.frames});

  static const int stride = 9;

  final String imageKey;
  final Float32List frames;
}

/// D272: a clip too big to keep as frames, drawn as it plays: each
/// playback reads it through its own [SvgaReader].
@immutable
class SvgaLive {
  const new(this.doc, this.scale, {this.resident});

  final SvgaDoc doc;

  /// Device pixels per canvas unit the pictures are decoded for.
  final double scale;

  /// D272b: a small clip's pictures, all decoded once and kept (shared by
  /// every playback: a combo replays at once); null: read through a
  /// window.
  final Map<String, ui.Image>? resident;
}

/// D272: one playback of a [SvgaLive] clip: the pictures of the next
/// [ahead] frames decoded (one at a time, off the UI thread), the ones
/// behind released. The first [want] completes when its frames are ready
/// (so the clip starts only when it can play smoothly).
class SvgaReader {
  new(this.live);

  final SvgaLive live;

  /// How far ahead the pictures are decoded: about a second.
  int get ahead => math.max(6, live.doc.fps);

  final _pictures = <String, ui.Image>{};
  final _failed = <String>{};
  int _cursor = 0;
  bool _loop = false;
  bool _running = false;
  bool _disposed = false;
  Completer<void>? _primed;

  /// The decoded pictures (for painting).
  Map<String, ui.Image> get pictures => live.resident ?? _pictures;

  /// How many pictures this playback holds now (tests: the window stays
  /// small; none for a resident clip).
  @visibleForTesting
  int get held => _pictures.length;

  Iterable<int> _window() sync* {
    final n = live.doc.frameCount;
    for (var i = 0; i <= ahead; i++) {
      final f = _cursor + i;
      if (f < n) {
        yield f;
      } else if (_loop) {
        yield f % n;
      }
    }
  }

  /// Every picture of [frame] is decoded.
  bool ready(int frame) {
    if (frame < 0 || frame >= live.doc.frameCount) return false;
    if (live.resident != null) return true;
    for (final key in live.doc.frameKeys[frame]) {
      if (!_pictures.containsKey(key) && !_failed.contains(key)) return false;
    }
    return true;
  }

  /// The clip is at [frame]: decodes ahead of it and releases what is
  /// behind. Returns when the window is decoded.
  Future<void> want(int frame, {bool loop = false}) {
    if (_disposed || live.resident != null) return Future.value();
    _cursor = frame.clamp(0, live.doc.frameCount - 1);
    _loop = loop;
    final keep = <String>{
      for (final f in [if (_cursor > 0) _cursor - 1, ..._window()])
        ...live.doc.frameKeys[f],
    };
    _pictures.removeWhere((key, image) {
      if (keep.contains(key)) return false;
      image.dispose();
      return true;
    });
    final primed = _primed ??= Completer<void>();
    if (!_running) unawaited(_run());
    return primed.future;
  }

  String? _next() {
    for (final f in _window()) {
      for (final key in live.doc.frameKeys[f]) {
        if (!_pictures.containsKey(key) && !_failed.contains(key)) return key;
      }
    }
    return null;
  }

  Future<void> _run() async {
    _running = true;
    try {
      while (!_disposed) {
        final key = _next();
        if (key == null) break;
        final image = await live.doc.decode(key, live.scale);
        if (_disposed) {
          image?.dispose();
          break;
        }
        if (image == null) {
          _failed.add(key);
        } else {
          _pictures[key]?.dispose();
          _pictures[key] = image;
        }
      }
    } finally {
      _running = false;
      final primed = _primed;
      _primed = null;
      if (primed != null && !primed.isCompleted) primed.complete();
    }
  }

  /// Releases every decoded picture.
  void dispose() {
    _disposed = true;
    for (final image in _pictures.values) {
      image.dispose();
    }
    _pictures.clear();
    final primed = _primed;
    _primed = null;
    if (primed != null && !primed.isCompleted) primed.complete();
  }
}

/// D272b: paints frame [frame] of [doc] from [pictures] into its box (the
/// canvas scaled to the box), nothing clipped: what a clip draws past its
/// canvas shows where its parent allows (a gift's drawn area).
class SvgaFramePainter extends CustomPainter {
  new({required this.doc, required this.frame, required this.pictures});

  final SvgaDoc doc;
  final int frame;
  final Map<String, ui.Image> pictures;

  @override
  void paint(Canvas canvas, Size size) {
    final box = doc.viewBox;
    if (box.isEmpty) return;
    canvas
      ..save()
      ..scale(size.width / box.width, size.height / box.height);
    doc.drawFrame(canvas, frame, pictures);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SvgaFramePainter old) =>
      old.doc != doc || old.frame != frame || old.pictures != pictures;
}

/// D272b: the shared, bounded caches of read files ([doc]) and of clips
/// ready to draw ([live]). A source is a hosted URL (the gift art cache,
/// downloaded once and kept on the device) or [asset] (the app's bundle).
abstract final class SvgaDocs {
  /// Fetches a source's bytes; tests replace it.
  static Future<Uint8List> Function(String source) fetch = _fetch;

  static Future<Uint8List> _fetch(String source) async {
    if (source.startsWith(assetPrefix)) {
      final data = await rootBundle.load(source.substring(assetPrefix.length));
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    if (!GiftArtCache.allowed(source)) {
      throw ArgumentError.value(source, 'source', 'not allowed');
    }
    return await GiftArtCache.instance.load(source);
  }

  static const assetPrefix = 'asset:';

  /// A bundled file's source.
  static String asset(String path) => '$assetPrefix$path';

  /// The read files kept (the latest last).
  static int maxDocs = 4;

  /// The most pixels of pictures one clip keeps decoded
  /// ([SvgaLive.resident]); a clip with more is read through a window as
  /// it plays.
  static int residentPixels = 12 * 1000 * 1000;

  /// The resident pictures kept over all clips.
  static int maxResidentPixels = 24 * 1000 * 1000;

  static final _docs = <String, Future<SvgaDoc?>>{};
  static final _lives = <String, Future<SvgaLive?>>{};
  static final _livePixels = <String, int>{};

  /// [source] read (null when it cannot be: tried again next time).
  static Future<SvgaDoc?> doc(String source) {
    final hit = _docs.remove(source);
    if (hit != null) {
      _docs[source] = hit; // most recently used last.
      return hit;
    }
    final future = () async {
      try {
        return await SvgaDoc.read(await fetch(source));
      } on Object catch (e) {
        debugPrint('SvgaDocs($source): $e');
        unawaited(_docs.remove(source));
        return null;
      }
    }();
    _docs[source] = future;
    while (_docs.length > math.max(1, maxDocs)) {
      unawaited(_docs.remove(_docs.keys.first));
    }
    return future;
  }

  /// Reads [source] ahead (downloaded, read on another isolate) so it
  /// plays at once when shown. Never throws.
  static Future<void> warm(String source) => doc(source).then((_) {});

  /// The bucket of [scale] device pixels per canvas unit: a power of two
  /// (from 1/8 to 16), so close sizes share a clip.
  static double bucket(double scale) {
    var b = 1 / 8;
    while (b < scale && b < 16) {
      b *= 2;
    }
    return b;
  }

  /// [source]'s clip to draw at [scale] device pixels per canvas unit: a
  /// small one with every picture decoded and kept, a big one read through
  /// a window by each playback ([SvgaReader]). Null when it cannot be read.
  static Future<SvgaLive?> live(String source, {required double scale}) {
    final k = bucket(scale);
    final key = '$k|$source';
    final hit = _lives.remove(key);
    if (hit != null) {
      _lives[key] = hit;
      return hit;
    }
    final future = _live(source, key, k);
    _lives[key] = future;
    return future;
  }

  static Future<SvgaLive?> _live(String source, String key, double k) async {
    final d = await doc(source);
    if (d == null) {
      unawaited(_lives.remove(key));
      return null;
    }
    final sizes = <String, ({int width, int height})>{};
    var pixels = 0;
    for (final name in d.images.keys) {
      if (!d.drawn.containsKey(name)) continue;
      final size = await d.naturalSize(name);
      if (size == null) continue;
      final s = d.decodeSize(name, size, k);
      sizes[name] = s;
      pixels += s.width * s.height;
    }
    if (pixels > residentPixels) return SvgaLive(d, k);
    final names = sizes.keys.toList();
    final images = await Future.wait([for (final n in names) d.decode(n, k)]);
    final resident = <String, ui.Image>{
      for (var i = 0; i < names.length; i++) names[i]: ?images[i],
    };
    _livePixels[key] = pixels;
    _evict(keep: key);
    return SvgaLive(d, k, resident: resident);
  }

  static void _evict({required String keep}) {
    var total = _livePixels.values.fold(0, (a, b) => a + b);
    while (total > maxResidentPixels) {
      final oldest = _lives.keys.firstWhere(
        (k) => k != keep && _livePixels.containsKey(k),
        orElse: () => '',
      );
      if (oldest.isEmpty) return;
      total -= _livePixels.remove(oldest) ?? 0;
      // (A playing clip keeps its pictures until it ends.)
      unawaited(_lives.remove(oldest));
    }
  }

  /// Forgets everything (tests).
  static void clear() {
    _docs.clear();
    _lives.clear();
    _livePixels.clear();
  }
}
