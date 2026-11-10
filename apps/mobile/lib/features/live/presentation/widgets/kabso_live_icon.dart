// D362 (owner: «ايقونة تكون ببطاقة البث من الخارج حسب نوع البث بخط صغير
// جداً لكي لا تأخذ مساحة»): the owner's white animated room-type glyphs for
// the live cards (the owner's file `kabso_live_icon.dart`, adapted to the
// repo: gen-l10n labels, `withValues`, analyzer and format clean).
//
// Glyphs: Phosphor Icons (video camera in the bold weight; microphone,
// headphones, game controller, lightning, users and gavel in the fill
// weight) — MIT, see apps/mobile/THIRD_PARTY_NOTICES.md — and the owner's
// own «PK» lettermark.
// Each glyph has its own looping micro-animation; reduce motion, `animate:
// false` (an off-screen card) or [KabsoLiveIcon.animationsEnabled] off
// (tests, goldens) draws one still frame.
//
// Copyright (c) 2023 Phosphor Icons (the glyph path data below).
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions: The above copyright notice and this permission
// notice shall be included in all copies or substantial portions of the
// Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
// USE OR OTHER DEALINGS IN THE SOFTWARE.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:path_drawing/path_drawing.dart';

/// The owner's nine room-type glyphs. Which room states use which glyph is
/// decided by the card (`LiveCardKind` in `live_type_tag.dart`); the file
/// keeps every glyph the owner drew, including those no room state backs yet
/// ([pk] lettermark, [pkGroup], [pkJudge], [podcastCam]).
enum KabsoLiveType {
  pk(1800),
  // Still at 0.05 of its loop: the bolt lit, before its shock ring (at 0
  // it is dimmed to 55 %).
  pkBolt(1600, rest: .05),
  pkGroup(1800),
  pkJudge(1500),
  voice(1600),
  cam(1400),
  podcastCam(2000),
  podcastVoice(1200),
  streamer(2000);

  new(this._periodMs, {this.rest = 0});

  final int _periodMs;

  /// The still frame (reduce motion, off screen, tests): a point of the
  /// loop, 0–1.
  final double rest;

  /// One loop of the glyph's animation.
  Duration get period => Duration(milliseconds: _periodMs);
}

/// The owner's live tag: the shared animated "live bars" ([KabsoLiveBars])
/// and a short room-type [label] (from gen-l10n; the caller passes it).
/// Drawn left to right in both directions, as in the owner's file.
class KabsoLiveTag extends StatelessWidget {
  const new({
    required this.label,
    super.key,
    this.iconSize = 14,
    this.fontSize = 12.5,
    this.color = const Color(0xFFFFFFFF),
    this.barColor = const Color(0xFFFF2B36),
    this.animate = true,
  });

  final String label;
  final double iconSize;
  final double fontSize;
  final Color color;
  final Color barColor;
  final bool animate;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KabsoLiveBars(size: iconSize, color: barColor, animate: animate),
        SizedBox(width: fontSize * .4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1,
            shadows: const [
              Shadow(
                color: Color(0x80000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Whether a looping glyph runs: the caller's [animate], the global switch
/// and the platform's reduce motion.
bool _runs(BuildContext context, {required bool animate}) =>
    animate &&
    KabsoLiveIcon.animationsEnabled &&
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

/// Three rounded bars rising and falling (1 s loop, staggered) — the "live
/// now" signal.
class KabsoLiveBars extends StatefulWidget {
  const new({
    super.key,
    this.size = 14,
    this.color = const Color(0xFFFF2B36),
    this.animate = true,
  });

  final double size;
  final Color color;
  final bool animate;

  @override
  State<KabsoLiveBars> createState() => _KabsoLiveBarsState();
}

class _KabsoLiveBarsState extends State<KabsoLiveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
    value: .25,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant KabsoLiveBars old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = _runs(context, animate: widget.animate);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c
        ..stop()
        ..value = .25;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _BarsPainter(_c, widget.color),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  new(this.anim, this.color) : super(repaint: anim);

  final Animation<double> anim;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 256;
    final t = anim.value;
    final shadow = Paint()
      ..color = const Color(0x59000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * .05);
    final fill = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final h = 60 + 150 * (.5 - .5 * math.cos(_tau * (t + i / 3)));
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH((38 + i * 70) * k, (236 - h) * k, 44 * k, h * k),
        Radius.circular(22 * k),
      );
      canvas
        ..drawRRect(r.shift(Offset(0, size.width * .03)), shadow)
        ..drawRRect(r, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter o) =>
      o.color != color || o.anim != anim;
}

/// One white room-type glyph, [size] square, with a soft shadow so it reads
/// on bright covers. Never mirrored (it is painted, not an icon font).
class KabsoLiveIcon extends StatefulWidget {
  const new({
    required this.type,
    super.key,
    this.size = 22,
    this.color = const Color(0xFFFFFFFF),
    this.animate = true,
    this.shadow = true,
    this.semanticLabel,
  });

  final KabsoLiveType type;
  final double size;
  final Color color;

  /// False draws the still frame (e.g. a card off screen).
  final bool animate;

  /// The soft shadow under the glyph.
  final bool shadow;

  /// The room type's name for screen readers (gen-l10n); null excludes the
  /// glyph from semantics (the card's own label names the type).
  final String? semanticLabel;

  /// Off in widget tests and goldens (a repeating animation never settles).
  static bool animationsEnabled = true;

  @override
  State<KabsoLiveIcon> createState() => _KabsoLiveIconState();
}

class _KabsoLiveIconState extends State<KabsoLiveIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.type.period,
    value: widget.type.rest,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant KabsoLiveIcon old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type) {
      _c.duration = widget.type.period;
      if (!_c.isAnimating) _c.value = widget.type.rest;
    }
    _sync();
  }

  void _sync() {
    final run = _runs(context, animate: widget.animate);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c
        ..stop()
        ..value = widget.type.rest;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyph = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _LivePainter(
          type: widget.type,
          anim: _c,
          color: widget.color,
          shadow: widget.shadow,
        ),
      ),
    );
    final label = widget.semanticLabel;
    return label == null
        ? ExcludeSemantics(child: glyph)
        : Semantics(label: label, image: true, child: glyph);
  }
}

// ───────────── glyph paths (256×256 box) ─────────────
// Phosphor Icons (MIT); P and K are the owner's lettermark (float noise
// rounded to 3 decimals, spaces written as commas).

const _pGavel =
    'M52.69,99.31a16,16,0,0,1,0-22.63l64-64a16,16,0,0,1,22.63,22.63l-64,6'
    '4a16,16,0,0,1-22.63,0Zm190.63,17.37a16,16,0,0,0-22.63,0l-64,64a16,16'
    ',0,0,0,0,22.63h0a16,16,0,0,0,22.63,0l64-64A16,16,0,0,0,243.32,116.68'
    'Zm-35.11-15.8L155.12,47.79a4,4,0,0,0-5.66,0L87.8,109.45a4,4,0,0,0,0,'
    '5.66L103,130.34,28.69,204.69a16,16,0,0,0,22.62,22.62L125.66,153l15.2'
    '3,15.23a4,4,0,0,0,5.66,0l61.66-61.66A4,4,0,0,0,208.21,100.88Z';

const _pMic =
    'M80,128V64a48,48,0,0,1,96,0v64a48,48,0,0,1-96,0Zm128,0a8,8,0,0,0-16,'
    '0,64,64,0,0,1-128,0,8,8,0,0,0-16,0,80.11,80.11,0,0,0,72,79.6V240a8,8'
    ',0,0,0,16,0V207.6A80.11,80.11,0,0,0,208,128Z';

const _pCam =
    'M249.45,69.31a12,12,0,0,0-12.51,1L212,88.43V72a20,20,0,0,0-20-20H32A'
    '20,20,0,0,0,12,72V184a20,20,0,0,0,20,20H192a20,20,0,0,0,20-20V167.57'
    'l24.94,18.14A12,12,0,0,0,256,176V80A12,12,0,0,0,249.45,69.31ZM188,18'
    '0H36V76H188Zm44-27.57-20-14.54V118.11l20-14.54Z';

const _pHeadphones =
    'M232,128v56a24,24,0,0,1-24,24H192a24,24,0,0,1-24-24V144a24,24,0,0,1,'
    '24-24h23.65a87.71,87.71,0,0,0-87-80H128a88,88,0,0,0-87.64,80H64a24,2'
    '4,0,0,1,24,24v40a24,24,0,0,1-24,24H48a24,24,0,0,1-24-24V128A104.11,1'
    '04.11,0,0,1,201.89,54.66,103.41,103.41,0,0,1,232,128Z';

const _pGamepad =
    'M247.44,173.75a.68.68,0,0,0,0-.14L231.05,89.44c0-.06,0-.12,0-.18A60.'
    '08,60.08,0,0,0,172,40H83.89a59.88,59.88,0,0,0-59,49.52L8.58,173.61a.'
    '68.68,0,0,0,0,.14,36,36,0,0,0,60.9,31.71l.35-.37L109.52,160h37l39.71'
    ',45.09c.11.13.23.25.35.37A36.08,36.08,0,0,0,212,216a36,36,0,0,0,35.4'
    '3-42.25ZM104,112H96v8a8,8,0,0,1-16,0v-8H72a8,8,0,0,1,0-16h8V88a8,8,0'
    ',0,1,16,0v8h8a8,8,0,0,1,0,16Zm40-8a8,8,0,0,1,8-8h24a8,8,0,0,1,0,16H1'
    '52A8,8,0,0,1,144,104Zm84.37,87.47a19.84,19.84,0,0,1-12.9,8.23A20.09,'
    '20.09,0,0,1,198,194.31L167.8,160H172a60,60,0,0,0,51-28.38l8.74,45A19'
    '.82,19.82,0,0,1,228.37,191.47Z';

const _pLetterP =
    'M32.759,75.773H82.601Q100.931,75.773,111.266,84.158Q121.601,92.543,1'
    '21.601,107.441Q121.601,116.567,118.169,124.796Q114.737,133.025,108.3'
    '41,139.187Q101.399,145.817,91.805,148.82Q82.211,151.823,67.703,151.8'
    '23H47.891L40.091,192.227H10.061ZM58.655,97.535,52.259,130.061H68.873'
    'Q79.481,130.061,85.097,125.069Q90.713,120.077,90.713,110.561Q90.713,'
    '104.243,86.696,100.889Q82.679,97.535,75.113,97.535Z';

const _pLetterK =
    'M138.299,75.773H168.329L160.139,117.659L209.669,75.773H245.939L179.1'
    '71,132.323L229.481,192.227H194.225L155.069,143.633L145.631,192.227H1'
    '15.601Z';

const _pUsers =
    'M64.12,147.8a4,4,0,0,1-4,4.2H16a8,8,0,0,1-7.8-6.17,8.35,8.35,0,0,1,1'
    '.62-6.93A67.79,67.79,0,0,1,37,117.51a40,40,0,1,1,66.46-35.8,3.94,3.9'
    '4,0,0,1-2.27,4.18A64.08,64.08,0,0,0,64,144C64,145.28,64,146.54,64.12'
    ',147.8Zm182-8.91A67.76,67.76,0,0,0,219,117.51a40,40,0,1,0-66.46-35.8'
    ',3.94,3.94,0,0,0,2.27,4.18A64.08,64.08,0,0,1,192,144c0,1.28,0,2.54-.'
    '12,3.8a4,4,0,0,0,4,4.2H240a8,8,0,0,0,7.8-6.17A8.33,8.33,0,0,0,246.17'
    ',138.89Zm-89,43.18a48,48,0,1,0-58.37,0A72.13,72.13,0,0,0,65.07,212,8'
    ',8,0,0,0,72,224H184a8,8,0,0,0,6.93-12A72.15,72.15,0,0,0,157.19,182.0'
    '7Z';

const _pBolt =
    'M213.85,125.46l-112,120a8,8,0,0,1-13.69-7l14.66-73.33L45.19,143.49a8'
    ',8,0,0,1-3-13l112-120a8,8,0,0,1,13.69,7L153.18,90.9l57.63,21.61a8,8,'
    '0,0,1,3,12.95Z';

final Map<String, Path> _cache = {};
Path _g(String d) => _cache[d] ??= parseSvgPathData(d);

// ───────────── easing ─────────────
const double _tau = math.pi * 2;
double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lin(double t, double a, double b) => _c01((t - a) / (b - a));
double _bump(double t, double a, double b) =>
    (t <= a || t >= b) ? 0 : math.sin(math.pi * (t - a) / (b - a));
double _eOut(double u) => 1 - math.pow(1 - u, 3).toDouble();
double _eIn(double u) => u * u * u;
double _eIO(double u) =>
    u < .5 ? 4 * u * u * u : 1 - math.pow(-2 * u + 2, 3) / 2;
double _el(double u) => u <= 0
    ? 0
    : (u >= 1
          ? 1
          : math.pow(2, -9 * u) * math.sin((u * 10 - .75) * _tau / 3) + 1);

class _LivePainter extends CustomPainter {
  new({
    required this.type,
    required this.anim,
    required this.color,
    required this.shadow,
  }) : super(repaint: anim);

  final KabsoLiveType type;
  final Animation<double> anim;
  final Color color;
  final bool shadow;

  late Canvas c;
  Color _ink = const Color(0xFFFFFFFF);

  Color _alpha(double o) => _ink.withValues(alpha: _c01(o) * _ink.a);

  Paint _f([double o = 1]) => Paint()..color = _alpha(o);

  Paint _s(double w, [double o = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _alpha(o);

  void _fill(String d, [double o = 1]) => c.drawPath(_g(d), _f(o));

  void _rot(double px, double py, double deg, void Function() f) {
    c
      ..save()
      ..translate(px, py)
      ..rotate(deg * math.pi / 180)
      ..translate(-px, -py);
    f();
    c.restore();
  }

  void _scl(double px, double py, double s, void Function() f) {
    c
      ..save()
      ..translate(px, py)
      ..scale(s)
      ..translate(-px, -py);
    f();
    c.restore();
  }

  void _arc(double cx, double cy, double r, double a0, double a1, Paint p) =>
      c.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        a0,
        a1 - a0,
        false,
        p,
      );

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    final t = anim.value;
    if (shadow) {
      final blur = size.width * .04;
      canvas
        ..saveLayer(
          Offset.zero & size,
          Paint()..imageFilter = ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        )
        ..translate(0, size.width * .03)
        ..scale(size.width / 256);
      _ink = const Color(0x73000000);
      _draw(t);
      canvas.restore();
    }
    _ink = color;
    canvas
      ..save()
      ..scale(size.width / 256);
    _draw(t);
    canvas.restore();
  }

  void _draw(double t) {
    switch (type) {
      case KabsoLiveType.pk:
        _pk(t);
      case KabsoLiveType.pkBolt:
        _pkBolt(t);
      case KabsoLiveType.pkGroup:
        _pkGroup(t);
      case KabsoLiveType.pkJudge:
        _judge(t);
      case KabsoLiveType.voice:
        _voice(t);
      case KabsoLiveType.cam:
        _cam(t);
      case KabsoLiveType.podcastCam:
        _podcastCam(t);
      case KabsoLiveType.podcastVoice:
        _podcastVoice(t);
      case KabsoLiveType.streamer:
        _streamer(t);
    }
  }

  // PK: letters pull apart, slam into the bolt, shake + shock ring.
  void _pk(double t) {
    const g = 26.0;
    final off = t < .3
        ? g + 10 * _eOut(t / .3)
        : t < .38
        ? g + 10 - 24 * _eIn((t - .3) / .08)
        : t < .85
        ? (g - 4) + 4 * _el(_c01((t - .38) / .47))
        : g;
    final fl = _bump(t, .38, .62);
    final sp = _lin(t, .38, .72);
    final sh = (t > .38 && t < .5)
        ? 3 * math.sin((t - .38) * 150) * (1 - (t - .38) / .12)
        : 0.0;
    c
      ..save()
      ..translate(sh, 0)
      ..save()
      ..translate(-off, 0);
    _fill(_pLetterP);
    c
      ..restore()
      ..save()
      ..translate(off, 0);
    _fill(_pLetterK);
    c.restore();
    _scl(128, 128, .42 + .1 * fl, () => _fill(_pBolt, .85 + .15 * fl));
    c.restore();
    if (sp > 0 && sp < 1) {
      c.drawCircle(
        const Offset(128, 128),
        30 + 80 * _eOut(sp),
        _s(9, (1 - sp) * .8),
      );
    }
  }

  // PK (compact): the bolt flashes twice with a shock ring.
  void _pkBolt(double t) {
    final fl = math.min(1, _bump(t, 0, .14) + _bump(t, .2, .3)).toDouble();
    final pop = 1 + .14 * _bump(t, 0, .3);
    final sp = _lin(t, .05, .45);
    _scl(128, 128, pop, () => _fill(_pBolt, .55 + .45 * fl));
    if (sp > 0 && sp < 1) {
      c.drawCircle(
        const Offset(128, 128),
        60 + 60 * _eOut(sp),
        _s(14, (1 - sp) * .8),
      );
    }
  }

  // PK جماعي: the team and a flashing bolt with sparks.
  void _pkGroup(double t) {
    final f = math.min(1, _bump(t, 0, .25) + _bump(t, .32, .5)).toDouble();
    final pop = 1 + .06 * _bump(t, .3, .55);
    _scl(128, 170, pop, () {
      c
        ..save()
        ..translate(0, 26);
      _scl(128, 128, .82, () => _fill(_pUsers));
      c.restore();
    });
    _scl(128, 46, .34 + .06 * f, () {
      c.translate(0, -80);
      _fill(_pBolt, .3 + .7 * f);
    });
    final sp = _lin(t, .32, .6);
    if (sp > 0 && sp < 1) {
      final p = _s(8, (1 - sp) * .8);
      final r = 26 + 30 * _eOut(sp);
      _arc(128, 46, r, math.pi * .9, math.pi * 1.3, p);
      _arc(128, 46, r, -math.pi * .1, math.pi * .3, p);
    }
  }

  // PK أحكام: the gavel winds up and strikes the block.
  void _judge(double t) {
    final a = t < .3
        ? -16 * _eOut(t / .3)
        : t < .38
        ? -16 + 52 * _eIn((t - .3) / .08)
        : t < .9
        ? 36 * (1 - _eIO(_c01((t - .5) / .4)))
        : 0.0;
    final imp = _lin(t, .38, .62);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(150, 228, 96, 18),
        const Radius.circular(9),
      ),
      _f(),
    );
    _rot(40, 222, a, () => _scl(128, 128, .9, () => _fill(_pGavel)));
    if (imp > 0 && imp < 1) {
      final p = _s(11, 1 - imp);
      final l = 16 + 26 * _eOut(imp);
      for (final d in const [
        [-1.0, -.9],
        [0.0, -1.0],
        [1.0, -.9],
      ]) {
        c.drawLine(
          Offset(198 + d[0] * 18, 212 + d[1] * 18),
          Offset(198 + d[0] * (18 + l), 212 + d[1] * (18 + l)),
          p,
        );
      }
    }
  }

  // بث صوتي: the mic breathes, sound waves travel outward.
  void _voice(double t) {
    _scl(
      128,
      128,
      1 + .03 * math.sin(_tau * t),
      () => _scl(128, 128, .86, () => _fill(_pMic)),
    );
    for (var k = 0; k < 2; k++) {
      final u = (t + k * .5) % 1;
      final r = 96 + 40 * _eOut(u);
      final p = _s(14, math.sin(math.pi * u) * .95);
      _arc(128, 104, r, math.pi * .78, math.pi * 1.22, p);
      _arc(128, 104, r, -math.pi * .22, math.pi * .22, p);
    }
  }

  // بث كام: the REC dot blinks with a pulse ring.
  void _cam(double t) {
    _fill(_pCam);
    final on = t < .55 ? 1.0 : .35 + .65 * _lin(t, .85, 1);
    final u = _lin(t, 0, .6);
    c.drawCircle(
      const Offset(100, 128),
      22 * (1 - .12 * _bump(t, 0, .25)),
      _f(on),
    );
    if (u < 1) {
      c
        ..save()
        ..clipRect(const Rect.fromLTWH(40, 76, 120, 104))
        ..drawCircle(
          const Offset(100, 128),
          22 + 30 * _eOut(u),
          _s(8, (1 - u) * .8),
        )
        ..restore();
    }
  }

  // بودكاست كام: the mic sways inside the camera frame with level bars.
  void _podcastCam(double t) {
    _fill(_pCam);
    c
      ..save()
      ..clipRect(const Rect.fromLTWH(36, 72, 128, 112));
    _rot(
      100,
      170,
      10 * math.sin(_tau * t),
      () => _scl(100, 128, .38, () {
        c.translate(0, -8);
        _fill(_pMic);
      }),
    );
    c.restore();
    for (var k = 0; k < 2; k++) {
      final h = 10 + 16 * math.sin(_tau * (t * 2 + k * .3)).abs();
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(128.0 + k * 14, 128 - h / 2, 8, h),
          const Radius.circular(4),
        ),
        _f(),
      );
    }
  }

  // بودكاست صوتي: headphones with a dancing equalizer.
  void _podcastVoice(double t) {
    _scl(128, 140, 1 + .025 * _bump(t, 0, .3), () => _fill(_pHeadphones));
    for (var k = 0; k < 4; k++) {
      final h = 18 + 46 * math.sin(math.pi * (t * 2 + k * .27)).abs();
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(95.0 + k * 19, 178 - h, 11, h),
          const Radius.circular(5.5),
        ),
        _f(),
      );
    }
  }

  // ستريمير: the gamepad wiggles under a live signal.
  void _streamer(double t) {
    final w = t < .4 ? 9 * math.sin(_tau * (t / .4) * 2) * (1 - t / .4) : 0.0;
    _rot(128, 160, w, () {
      c
        ..save()
        ..translate(0, 34);
      _scl(128, 128, .82, () => _fill(_pGamepad));
      c.restore();
    });
    for (var k = 0; k < 2; k++) {
      final u = (t + k * .5) % 1;
      _arc(
        128,
        70,
        20 + 28 * k + 16 * _eOut(u),
        math.pi * 1.2,
        math.pi * 1.8,
        _s(13, math.sin(math.pi * u)),
      );
    }
    c.drawCircle(const Offset(128, 70), 9, _f());
  }

  @override
  bool shouldRepaint(covariant _LivePainter o) =>
      o.type != type ||
      o.color != color ||
      o.anim != anim ||
      o.shadow != shadow;
}
