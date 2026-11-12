import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/scheduler.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/status/status_catalogue.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// D376 «الحالة»: how a status is drawn over a picture.
enum StatusEmojiMotion {
  /// Emoji rise from the top of the picture like bubbles, sway, swell and
  /// pop with a small burst of sparkles (the profile header, the preview,
  /// the speakers' seats).
  bubbles,

  /// One still emoji above the head (busy seat rows; reduced motion).
  still,

  /// A small still emoji on the picture's top end corner (comments, long
  /// lists).
  badge,
}

/// Sizes and colours of the status effect (owner's pack: profile 60, seat
/// 34, comments 20 — picture radii).
abstract final class KStatusEmoji {
  /// The rise above the picture's centre, in picture radii, at
  /// `riseFactor` 1 (about 2.9 radii to the top of a bubble).
  static const double riseMin = 1.4;
  static const double riseMax = 1.9;

  /// A bubble's lifetime and its pop (the last 14 %).
  static const int lifeMinMs = 2400;
  static const int lifeMaxMs = 3600;
  static const double popAt = 0.86;
  static const int burstMs = 650;

  /// The still emoji above the head and the corner badge, in picture
  /// diameters.
  static const double still = 0.6;
  static const double badge = 0.55;

  /// The sparkles of a burst (design-token colours).
  static const List<Color> sparkles = [
    KBrandColors.gold,
    Color(0xFFFFFFFF),
    KLiveColors.pkLeft,
    KLiveColors.pkRight,
  ];

  /// Bubbles alive at once for a picture of [radius].
  static int countFor(double radius) => radius >= 50
      ? 6
      : radius >= 28
      ? 5
      : 4;
}

/// The status emoji's Lottie compositions, loaded once per asset and shared
/// by every picture that shows it (one parse, one drawable per layer).
abstract final class StatusEmojiArt {
  static final Map<String, LottieComposition> _loaded = {};
  static final Map<String, Future<LottieComposition>> _pending = {};

  /// The composition of [asset], loaded once.
  static Future<LottieComposition> load(String asset) {
    final done = _loaded[asset];
    if (done != null) return SynchronousFuture(done);
    return _pending[asset] ??= AssetLottie(asset).load().then((c) {
      _loaded[asset] = c;
      _pending.remove(asset)?.ignore();
      return c;
    });
  }

  /// The composition of [asset] if already loaded.
  static LottieComposition? peek(String asset) => _loaded[asset];

  /// Loads [assets] ahead (tests and goldens, before the first frame).
  static Future<void> precache(Iterable<String> assets) =>
      Future.wait(assets.map(load));
}

/// D376 «الحالة»: the status [emoji] over a picture of [radius], drawn in
/// the box it is given (`Positioned.fill` over the picture's box; the
/// picture is centred in it). Bubbles go above the box (no clip) and never
/// take taps.
///
/// One ticker and one Lottie drawable per layer; the bubbles are a pure
/// function of the time (no per-frame allocation, no rebuild — only this
/// layer repaints). The ticker runs only while the layer is on screen
/// ([VisibilityDetector]) and its route is current ([TickerMode]); reduced
/// motion ([MediaQuery.disableAnimationsOf]) draws the still emoji instead.
class StatusEmojiLayer extends StatefulWidget {
  const new(
    this.emoji, {
    required this.radius,
    super.key,
    this.motion = StatusEmojiMotion.bubbles,
    this.riseFactor = 1,
    this.count,
    this.semantics = true,
  });

  final StatusEmoji emoji;

  /// The picture's radius.
  final double radius;
  final StatusEmojiMotion motion;

  /// Lower than 1 when there is little room above the picture.
  final double riseFactor;

  /// Bubbles alive at once ([KStatusEmoji.countFor] by default).
  final int? count;

  /// Whether screen readers hear «الحالة: …» (off where the picture is
  /// already read with the person, e.g. a seat).
  final bool semantics;

  /// Tests and goldens: a fixed moment of the bubbles (no ticker, frames
  /// settle). Null in the app.
  static Duration? debugTime;

  static Key keyOf(String id) => Key('statusEmoji.$id');

  @override
  State<StatusEmojiLayer> createState() => _StatusEmojiLayerState();
}

class _StatusEmojiLayerState extends State<StatusEmojiLayer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _time = ValueNotifier<Duration>(Duration.zero);
  LottieDrawable? _drawable;
  bool _visible = true;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StatusEmojiLayer old) {
    super.didUpdateWidget(old);
    if (old.emoji.asset != widget.emoji.asset) {
      _drawable = null;
      _load();
    }
  }

  void _load() {
    final asset = widget.emoji.asset;
    final ready = StatusEmojiArt.peek(asset);
    if (ready != null) {
      _drawable = LottieDrawable(ready);
      return;
    }
    unawaited(
      StatusEmojiArt.load(asset).then(
        (c) {
          if (!mounted || widget.emoji.asset != asset) return;
          setState(() => _drawable = LottieDrawable(c));
        },
        onError: (Object _) {
          // A missing asset shows nothing (never a crash over a picture).
        },
      ),
    );
  }

  void _sync(bool moving) {
    _moving = moving;
    final run = moving && _visible && StatusEmojiLayer.debugTime == null;
    if (run) {
      _ticker ??= createTicker((elapsed) => _time.value = elapsed);
      if (!_ticker!.isActive) _ticker!.start();
    } else if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final motion = reduced && widget.motion == StatusEmojiMotion.bubbles
        ? StatusEmojiMotion.still
        : widget.motion;
    final moving = motion == StatusEmojiMotion.bubbles;
    _sync(moving);
    final drawable = _drawable;
    Widget layer = drawable == null
        ? const SizedBox.expand()
        : CustomPaint(
            size: Size.infinite,
            painter: moving
                ? _BubblesPainter(
                    drawable: drawable,
                    time: _time,
                    fixed: StatusEmojiLayer.debugTime,
                    radius: widget.radius,
                    rise: widget.riseFactor,
                    count: widget.count ?? KStatusEmoji.countFor(widget.radius),
                    seed: widget.emoji.id.hashCode,
                    faceSway: widget.emoji.faceSway,
                  )
                : _StillPainter(
                    drawable: drawable,
                    radius: widget.radius,
                    badge: motion == StatusEmojiMotion.badge,
                    rtl: Directionality.of(context) == TextDirection.rtl,
                    stillAt: widget.emoji.stillAt,
                  ),
          );
    if (moving) {
      layer = VisibilityDetector(
        key: ObjectKey(this),
        onVisibilityChanged: (info) {
          if (!mounted) return;
          _visible = info.visibleFraction > 0;
          _sync(_moving);
        },
        child: RepaintBoundary(child: layer),
      );
    }
    final semantic = widget.semantics
        ? Semantics(
            key: StatusEmojiLayer.keyOf(widget.emoji.id),
            label: context.l10n.statusSemantics(
              widget.emoji.label(context.l10n),
            ),
            image: true,
            child: ExcludeSemantics(child: layer),
          )
        : ExcludeSemantics(
            key: StatusEmojiLayer.keyOf(widget.emoji.id),
            child: layer,
          );
    return IgnorePointer(child: semantic);
  }
}

/// A bubble of generation `gen` of slot `slot`, as a pure function of the
/// seed (the same picture draws the same bubbles every run).
@immutable
final class _Bubble {
  factory of(int seed, int slot, int gen, double r, double rise) {
    final rnd = math.Random(seed ^ (slot * 7919) ^ (gen * 104729));
    double between(double a, double b) => a + rnd.nextDouble() * (b - a);
    return _Bubble._(
      size: r * between(0.32, 0.72),
      x0: r * between(-0.75, 0.75),
      rise: r * between(KStatusEmoji.riseMin, KStatusEmoji.riseMax) * rise,
      amp: r * between(0.12, 0.28),
      freq: between(1.6, 2.6),
      phase: between(0, 2 * math.pi),
      tilt: between(-22, 22) * math.pi / 180,
      sparkSeed: rnd.nextInt(1 << 30),
    );
  }

  const new _({
    required this.size,
    required this.x0,
    required this.rise,
    required this.amp,
    required this.freq,
    required this.phase,
    required this.tilt,
    required this.sparkSeed,
  });

  final double size;
  final double x0;
  final double rise;
  final double amp;
  final double freq;
  final double phase;
  final double tilt;
  final int sparkSeed;

  double _wave(double t) => math.sin(t * freq * 2 * math.pi + phase);

  /// The position from the picture's centre at progress [t] (0…1): fast
  /// start, slowing down, swaying more as it rises.
  Offset at(double t, double r) {
    final eased = 1 - math.pow(1 - t, 1.6).toDouble();
    return Offset(x0 + _wave(t) * amp * (0.4 + t), -0.75 * r - rise * eased);
  }

  /// Moving toward the end side (for `StatusEmoji.faceSway`).
  bool movingRight(double t) => math.cos(t * freq * 2 * math.pi + phase) > 0;
}

class _BubblesPainter extends CustomPainter {
  new({
    required this.drawable,
    required this.time,
    required this.fixed,
    required this.radius,
    required this.rise,
    required this.count,
    required this.seed,
    required this.faceSway,
  }) : super(repaint: time);

  final LottieDrawable drawable;
  final ValueNotifier<Duration> time;
  final Duration? fixed;
  final double radius;
  final double rise;
  final int count;
  final int seed;
  final bool faceSway;

  static final Paint _fade = Paint();
  static final Paint _spark = Paint()..style = PaintingStyle.fill;

  /// Slot [i]'s lifetime and start (staggered so they do not rise together).
  (int life, int offset) _slot(int i) {
    final rnd = math.Random(seed ^ (i * 31337));
    final life =
        KStatusEmoji.lifeMinMs +
        rnd.nextInt(KStatusEmoji.lifeMaxMs - KStatusEmoji.lifeMinMs);
    return (life, (i * (life / count)).round() + rnd.nextInt(400));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final now = (fixed ?? time.value).inMilliseconds;
    final centre = size.center(Offset.zero);
    final composition = drawable.composition;
    // One frame of the emoji for every bubble (one layer update per frame).
    drawable.setProgress((now / composition.duration.inMilliseconds) % 1.0);
    for (var i = 0; i < count; i++) {
      final (life, offset) = _slot(i);
      final local = now - offset;
      if (local < 0) continue;
      final gen = local ~/ life;
      final t = (local % life) / life;
      final b = _Bubble.of(seed, i, gen, radius, rise);
      _bubble(canvas, centre, b, t);
      // The burst of this generation, or of the previous one just after.
      final popMs = (KStatusEmoji.popAt * life).round();
      final sinceOwnPop = (local % life) - popMs;
      if (sinceOwnPop >= 0) {
        _burst(canvas, centre, b, KStatusEmoji.popAt, sinceOwnPop);
      } else if (gen > 0 &&
          (local % life) + life - popMs < KStatusEmoji.burstMs) {
        final prev = _Bubble.of(seed, i, gen - 1, radius, rise);
        _burst(
          canvas,
          centre,
          prev,
          KStatusEmoji.popAt,
          (local % life) + life - popMs,
        );
      }
    }
  }

  void _bubble(Canvas canvas, Offset centre, _Bubble b, double t) {
    var scale = t < 0.15 ? 0.3 + 0.7 * (t / 0.15) : 1.0;
    var opacity = t < 0.1 ? t / 0.1 : 1.0;
    if (t > KStatusEmoji.popAt) {
      final q = (t - KStatusEmoji.popAt) / (1 - KStatusEmoji.popAt);
      scale = 1 + 0.35 * q;
      opacity = 1 - q;
    }
    if (opacity <= 0.01) return;
    final p = centre + b.at(t, radius);
    final wobble = b._wave(t) * 8 * math.pi / 180;
    final flip = faceSway && b.movingRight(t);
    final half = b.size / 2;
    canvas
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(b.tilt + wobble)
      ..scale(flip ? -scale : scale, scale);
    final box = Rect.fromLTRB(-half, -half, half, half);
    if (opacity < 0.99) {
      canvas.saveLayer(
        box.inflate(half),
        _fade..color = Color.fromRGBO(0, 0, 0, opacity),
      );
      drawable.draw(canvas, box, fit: BoxFit.contain);
      canvas.restore();
    } else {
      drawable.draw(canvas, box, fit: BoxFit.contain);
    }
    canvas.restore();
  }

  /// Four-point sparkles flying out from where the bubble popped.
  void _burst(Canvas canvas, Offset centre, _Bubble b, double popT, int ms) {
    if (ms > KStatusEmoji.burstMs) return;
    final p = ms / KStatusEmoji.burstMs;
    final at = centre + b.at(popT, radius);
    final rnd = math.Random(b.sparkSeed);
    final n = radius > 40 ? 6 : 4;
    final grow = p < 0.4 ? (p / 0.4) * 1.1 : 1.1 * (1 - (p - 0.4) / 0.6);
    final alpha = p < 0.4 ? 1.0 : 1 - (p - 0.4) / 0.6;
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi + (rnd.nextDouble() - 0.5) * 0.6;
      final reach = b.size * (0.6 + rnd.nextDouble() * 0.4);
      final star = b.size * (0.22 + rnd.nextDouble() * 0.14) * grow;
      if (star <= 0.5) continue;
      final d = reach * Curves.easeOut.transform(p);
      final c = at + Offset(math.cos(a) * d, math.sin(a) * d);
      final colour = KStatusEmoji.sparkles[i % KStatusEmoji.sparkles.length];
      _spark.color = colour.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawPath(_star(c, star, p * math.pi), _spark);
    }
  }

  static Path _star(Offset c, double s, double rotation) {
    final outer = s / 2;
    final inner = s * 0.17;
    final path = Path();
    for (var k = 0; k < 8; k++) {
      final r = k.isEven ? outer : inner;
      final ang = rotation - math.pi / 2 + k * math.pi / 4;
      final pt = c + Offset(math.cos(ang) * r, math.sin(ang) * r);
      if (k == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter old) =>
      old.drawable != drawable ||
      old.fixed != fixed ||
      old.radius != radius ||
      old.rise != rise ||
      old.count != count ||
      old.seed != seed ||
      old.faceSway != faceSway;
}

class _StillPainter extends CustomPainter {
  new({
    required this.drawable,
    required this.radius,
    required this.badge,
    required this.rtl,
    this.stillAt = 0,
  });

  final LottieDrawable drawable;
  final double radius;
  final bool badge;
  final bool rtl;
  final double stillAt;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    drawable.setProgress(stillAt);
    if (badge) {
      // On the top end corner, over the picture's edge.
      final s = 2 * radius * KStatusEmoji.badge;
      final d = radius * math.sqrt1_2;
      final c = centre + Offset(rtl ? -d : d, -d);
      drawable.draw(canvas, Rect.fromCenter(center: c, width: s, height: s));
      return;
    }
    final s = 2 * radius * KStatusEmoji.still;
    final c = centre + Offset(0, -radius * 1.2);
    drawable.draw(canvas, Rect.fromCenter(center: c, width: s, height: s));
  }

  @override
  bool shouldRepaint(covariant _StillPainter old) =>
      old.drawable != drawable ||
      old.radius != radius ||
      old.badge != badge ||
      old.stillAt != stillAt ||
      old.rtl != rtl;
}

/// A picture with its status: [child] (the picture, [radius] its radius)
/// and, when [statusEmojiId] is one this app knows, the status over it.
class StatusAvatar extends StatelessWidget {
  const new({
    required this.child,
    required this.radius,
    required this.statusEmojiId,
    super.key,
    this.motion = StatusEmojiMotion.bubbles,
    this.riseFactor = 1,
    this.semantics = true,
  });

  final Widget child;
  final double radius;
  final String? statusEmojiId;
  final StatusEmojiMotion motion;
  final double riseFactor;
  final bool semantics;

  @override
  Widget build(BuildContext context) {
    final emoji = StatusCatalogue.byId(statusEmojiId);
    if (emoji == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: StatusEmojiLayer(
            emoji,
            radius: radius,
            motion: motion,
            riseFactor: riseFactor,
            semantics: semantics,
          ),
        ),
      ],
    );
  }
}
