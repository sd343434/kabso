// Kabso — PK support bar with Kabi living on the dividing line (owner's
// widget, D73). Restyled for the project's lints only; the behaviour is
// the owner's. Additions: [KabsoPkBar.formatScore] (the old bar's grouped
// numbers), [KabsoPkBar.enabled] (tests) and reduced motion.
//
// One Lottie file (`assets/pk/kabi_pk.json`), six marked segments:
//   idle   – loops: blinks, looks at both teams, antennae sway
//   push   – loops: leans and pushes the line in the direction it moves
//            (mirrored for the left)
//   fire   – loops: powered push, antennae + eye on fire, flame aura (big
//            support burst)
//   tense  – loops: shivers, sweat, hands on mouth (last seconds of the
//            round)
//   win    – once: jumps with arms up toward the winning side
//   cheer  – once: little wave / hop, played every few seconds while idle
//
// Pass the cumulative scores; the widget decides what Kabi does.

import 'dart:async';
import 'dart:math' as math;

import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

enum KabsoPkResult { leftWins, rightWins, draw }

/// The PK score bar with Kabi on the seam. Laid out left-to-right in both
/// languages: [left] is the team drawn on the left. Kabi and the flames
/// paint above the bar (`Clip.none`): keep about 40 lp free above it.
class KabsoPkBar extends StatefulWidget {
  const new({
    required this.left,
    required this.right,
    super.key,
    this.remaining,
    this.result,
    this.height = 22,
    this.kabiSize = 58,
    this.fireShare = .06,
    this.tenseUnder = const Duration(seconds: 10),
    this.leftColors = const [Color(0xFFC2000B), Color(0xFFFF3B30)],
    this.rightColors = const [Color(0xFFFF8A00), Color(0xFFFFC233)],
    this.asset = 'assets/pk/kabi_pk.json',
    this.formatScore,
  });

  final int left;
  final int right;
  final Duration? remaining;
  final KabsoPkResult? result;
  final double height;
  final double kabiSize;

  /// A gain of at least this share of the total within ~3 s sets Kabi (and
  /// that side of the bar) on fire.
  final double fireShare;
  final Duration tenseUnder;

  /// Each side's fill, from its outer edge to the seam.
  final List<Color> leftColors;
  final List<Color> rightColors;
  final String asset;

  /// How a score is written (default: plain digits).
  final String Function(int score)? formatScore;

  /// Widget tests and goldens draw the bar and seam but skip Kabi's Lottie,
  /// the looping flames and the gesture timer (they run forever and would
  /// keep fake time busy); set by `test/flutter_test_config.dart`.
  static bool enabled = true;

  @override
  State<KabsoPkBar> createState() => _KabsoPkBarState();
}

enum _Mode { idle, push, fire, tense, win, cheer }

class _KabsoPkBarState extends State<KabsoPkBar> with TickerProviderStateMixin {
  late final AnimationController _ratio = AnimationController(
    vsync: this,
    value: _target(),
  );
  late final AnimationController _kabi = AnimationController(vsync: this);
  late final AnimationController _flame = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  final _rnd = math.Random();

  LottieComposition? _comp;
  _Mode _mode = _Mode.idle;
  bool _faceLeft = false;
  int _fireSide = 0; // -1 left side burning, 1 right side, 0 none
  Timer? _calm;
  Timer? _gesture;
  final _gains = <(DateTime, int, int)>[];

  /// Reduced motion (or tests): no loops, Kabi holds a still frame.
  bool _still = false;

  double _target() {
    final t = widget.left + widget.right;
    return t <= 0 ? .5 : (widget.left / t).clamp(.04, .96);
  }

  @override
  void initState() {
    super.initState();
    if (KabsoPkBar.enabled) {
      _flame.repeat();
      _scheduleGesture();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        !KabsoPkBar.enabled || MediaQuery.disableAnimationsOf(context);
    if (still == _still) return;
    _still = still;
    if (still) {
      _flame.stop();
      _gesture?.cancel();
    } else if (KabsoPkBar.enabled) {
      _flame.repeat();
      _scheduleGesture();
    }
    _playSegment();
  }

  @override
  void didUpdateWidget(KabsoPkBar old) {
    super.didUpdateWidget(old);
    if (widget.result != null && old.result == null) {
      return _finish(widget.result!);
    }
    if (widget.result != null) return;
    // A new round (result cleared): back to waiting.
    if (old.result != null) {
      _fireSide = 0;
      _gains.clear();
      _set(_Mode.idle);
    }
    final dl = widget.left - old.left;
    final dr = widget.right - old.right;
    if (dl != 0 || dr != 0) {
      _ratio.animateTo(
        _target(),
        duration: _still ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
      // A reset to a new round is not a push.
      if (dl >= 0 && dr >= 0) _onGain(dl, dr);
    } else {
      _checkTense();
    }
  }

  void _onGain(int dl, int dr) {
    final now = DateTime.now();
    _gains
      ..add((now, math.max(dl, 0), math.max(dr, 0)))
      ..removeWhere((g) => now.difference(g.$1) > const Duration(seconds: 3));
    final total = math.max(1, widget.left + widget.right);
    final l3 = _gains.fold<int>(0, (s, g) => s + g.$2);
    final r3 = _gains.fold<int>(0, (s, g) => s + g.$3);
    final leftPushes = dl >= dr; // left team gaining → line moves right
    final share = (leftPushes ? l3 : r3) / total;
    _faceLeft = !leftPushes;
    if (share >= widget.fireShare) {
      _fireSide = leftPushes ? -1 : 1;
      _set(_Mode.fire);
      _calmAfter(const Duration(milliseconds: 2600));
    } else if (_mode != _Mode.fire) {
      _set(_Mode.push);
      _calmAfter(const Duration(milliseconds: 1300));
    }
  }

  void _calmAfter(Duration d) {
    _calm?.cancel();
    _calm = Timer(d, () {
      if (!mounted || widget.result != null) return;
      _fireSide = 0;
      _set(_Mode.idle);
      _checkTense();
    });
  }

  void _checkTense() {
    final r = widget.remaining;
    final tense = r != null && r > Duration.zero && r <= widget.tenseUnder;
    if (tense && _mode == _Mode.idle) _set(_Mode.tense);
    if (!tense && _mode == _Mode.tense) _set(_Mode.idle);
  }

  void _finish(KabsoPkResult r) {
    _calm?.cancel();
    _fireSide = 0;
    _faceLeft = r == KabsoPkResult.leftWins;
    _set(r == KabsoPkResult.draw ? _Mode.cheer : _Mode.win);
  }

  void _scheduleGesture() {
    _gesture?.cancel();
    _gesture = Timer(Duration(milliseconds: 5000 + _rnd.nextInt(5000)), () {
      if (!mounted) return;
      if (_mode == _Mode.idle && widget.result == null) {
        _faceLeft = _rnd.nextBool();
        _set(_Mode.cheer);
      }
      _scheduleGesture();
    });
  }

  // ───── Lottie segment control ─────
  void _set(_Mode m) {
    if (_mode == m && _kabi.isAnimating && m != _Mode.cheer) {
      setState(() {});
      return;
    }
    setState(() => _mode = m);
    _playSegment();
  }

  void _playSegment() {
    final c = _comp;
    if (c == null) return;
    final mk = c.getMarker(_mode.name);
    if (mk == null) return;
    final total = c.endFrame - c.startFrame;
    final a = (mk.startFrame - c.startFrame) / total;
    final b =
        ((mk.startFrame + mk.durationFrames) - c.startFrame) / total - .0005;
    final period = Duration(
      milliseconds: (mk.durationFrames / c.frameRate * 1000).round(),
    );
    _kabi.stop();
    if (_still) {
      // The segment's middle, held.
      _kabi.value = (a + b) / 2;
      return;
    }
    if (_mode == _Mode.win || _mode == _Mode.cheer) {
      _kabi.value = a;
      unawaited(
        _kabi.animateTo(b, duration: period).whenComplete(() {
          if (!mounted || _mode == _Mode.win || widget.result != null) return;
          if (_mode == _Mode.cheer) {
            _set(_Mode.idle);
            _checkTense();
          }
        }),
      );
    } else {
      _kabi.value = a;
      _kabi.repeat(min: a, max: b, period: period);
    }
  }

  @override
  void dispose() {
    _calm?.cancel();
    _gesture?.cancel();
    _ratio.dispose();
    _kabi.dispose();
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final k = widget.kabiSize;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: h,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            return AnimatedBuilder(
              animation: Listenable.merge([_ratio, _flame]),
              builder: (context, _) {
                final x = w * _ratio.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // bar
                    Positioned.fill(
                      child: Row(
                        children: [
                          SizedBox(
                            width: x,
                            child: _side(widget.leftColors, widget.left, true),
                          ),
                          Expanded(
                            child: _side(
                              widget.rightColors,
                              widget.right,
                              false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // flames on the boosting side
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: h * .8,
                      height: h * 1.5,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _fireSide == 0 ? 0 : 1,
                          duration: const Duration(milliseconds: 350),
                          child: CustomPaint(
                            painter: _FlamesPainter(
                              t: _flame.value,
                              from: _fireSide < 0 ? 0 : x,
                              to: _fireSide < 0 ? x : w,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // glowing seam
                    Positioned(
                      left: x - h,
                      top: -h * .3,
                      width: h * 2,
                      height: h * 1.6,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(
                                  alpha:
                                      _mode == _Mode.idle ||
                                          _mode == _Mode.tense
                                      ? .55
                                      : .9,
                                ),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Kabi
                    Positioned(
                      left: x - k / 2,
                      bottom: h * .25,
                      width: k,
                      height: k,
                      child: IgnorePointer(
                        child: !KabsoPkBar.enabled
                            ? const SizedBox.shrink()
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.diagonal3Values(
                                  _faceLeft ? -1 : 1,
                                  1,
                                  1,
                                ),
                                child: Lottie.asset(
                                  widget.asset,
                                  controller: _kabi,
                                  onLoaded: (c) {
                                    _comp = c;
                                    _playSegment();
                                  },
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _side(List<Color> colors, int score, bool left) {
    final h = widget.height;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: left ? colors : colors.reversed.toList(),
        ),
      ),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.symmetric(horizontal: h * .35),
      child: FittedBox(
        child: Text(
          widget.formatScore?.call(score) ?? '$score',
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: h * .62,
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: const [
              Shadow(
                color: Color(0x88000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlamesPainter extends CustomPainter {
  new({required this.t, required this.from, required this.to});

  final double t;
  final double from;
  final double to;

  @override
  void paint(Canvas canvas, Size size) {
    if (to - from < 4) return;
    final n = math.max(3, ((to - from) / 14).round());
    final step = (to - from) / n;
    for (var layer = 0; layer < 3; layer++) {
      final colors = [
        [const Color(0xFFB0000E), const Color(0x00FF3B00)],
        [const Color(0xFFFF6A00), const Color(0x00FFB000)],
        [const Color(0xFFFFE27A), const Color(0x00FFFFFF)],
      ][layer];
      final hScale = [1.0, .72, .45][layer];
      for (var i = 0; i < n; i++) {
        final cx = from + step * (i + .5);
        final ph = t * 2 * math.pi + i * 1.7 + layer;
        final fh = size.height * hScale * (.62 + .38 * math.sin(ph).abs());
        final fw = step * (1.25 - layer * .25);
        final base = size.height;
        final sway = math.sin(ph * 1.3) * fw * .18;
        final p = Path()
          ..moveTo(cx - fw / 2, base)
          ..quadraticBezierTo(
            cx - fw * .55,
            base - fh * .45,
            cx + sway,
            base - fh,
          )
          ..quadraticBezierTo(cx + fw * .55, base - fh * .45, cx + fw / 2, base)
          ..close();
        final paint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: colors,
          ).createShader(Rect.fromLTWH(cx - fw / 2, base - fh, fw, fh));
        canvas.drawPath(p, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FlamesPainter old) =>
      old.t != t || old.from != from || old.to != to;
}
