// v1.115-social (D354, CONVENTIONS §10.150): the five large, animated event
// countdowns of a designed page (FLIP, RING, COINS, NEON, RIBBON; CLASSIC is
// today's pill), promoted from the KL-352 prototype.
//
// Motion rules shared by every style:
// - ONE continuous animation: a single [Ticker] drives the per-second digit
//   change and the style's ambient effect (shimmer, flicker, sparkles).
//   Only this subtree rebuilds; heavy drawing is in CustomPainters.
// - Reduce motion (MediaQuery.disableAnimations): no ticker; a 1 s timer
//   updates the digits with no transition and no ambient effect.
// - Digits are tabular and laid out left-to-right inside RTL (DD HH MM SS).
// - Final hour: red urgency pulse. Ended: «انتهت الفعالية».

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

enum HeroCountdownStyle {
  /// 1. Split-flap cards, gold on wine; each changed card flips.
  flip,

  /// 2. A ring that depletes over the event, a shimmer runs along it.
  ring,

  /// 3. Gold coins; a changed coin spins on its axis.
  coins,

  /// 4. Seven-segment neon with glow, a faint flicker and scanlines.
  neon,

  /// 5. A ribbon banner with odometer digits and sparkles.
  ribbon,
}

// Palette (brand gold / red tokens + wine shades of the event page).
const Color _gold = KBrandColors.gold; // F5C451
const _goldLight = Color(0xFFFFE7A3);
const _goldDeep = Color(0xFFB9832A);
const _wine = Color(0xFF2A0508);
const _wineMid = Color(0xFF5A0A10);
const Color _red = KBrandColors.red500;
const Color _redLight = KBrandColors.red400;

/// The state of the countdown for one frame.
@immutable
class CountdownSnap {
  const new({
    required this.cur,
    required this.prev,
    required this.t,
    required this.loop,
    required this.fractionLeft,
    required this.urgent,
    required this.ended,
    required this.starts,
    required this.motion,
  });

  /// Days, hours, minutes, seconds now and one second earlier.
  final List<int> cur;
  final List<int> prev;

  /// Progress of the digit change of this second, 0 → 1 (1 = settled).
  final double t;

  /// Seconds since the countdown appeared (ambient effects).
  final double loop;

  /// Share of the event still to run (1 → 0).
  final double fractionLeft;
  final bool urgent;
  final bool ended;
  final bool starts;
  final bool motion;

  bool changed(int unit) => cur[unit] != prev[unit];

  /// 0 → 1 → 0 once per second (urgency pulse), 0 with reduced motion.
  double get pulse => motion ? math.sin(math.pi * (loop % 1)).abs() : 0;

  static String two(int v) => v.clamp(0, 99).toString().padLeft(2, '0');
}

class EventHeroCountdown extends StatefulWidget {
  const new({
    required this.startsAt,
    required this.endsAt,
    required this.style,
    this.reduceMotion,
    super.key,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final HeroCountdownStyle style;

  /// Overrides MediaQuery.disableAnimations (captures).
  final bool? reduceMotion;

  /// Tests: the clock at the moment the countdown appears.
  static DateTime Function()? debugClock;

  static const key0 = Key('event.heroCountdown');

  @override
  State<EventHeroCountdown> createState() => _EventHeroCountdownState();
}

class _EventHeroCountdownState extends State<EventHeroCountdown>
    with SingleTickerProviderStateMixin {
  late final DateTime _t0 = (EventHeroCountdown.debugClock ?? DateTime.now)();
  late final Ticker _ticker = createTicker((e) => _elapsed.value = e);
  final _elapsed = ValueNotifier<Duration>(Duration.zero);
  Timer? _timer;
  bool _motion = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion =
        !(widget.reduceMotion ?? MediaQuery.disableAnimationsOf(context));
    if (motion == _motion && (_ticker.isActive || _timer != null)) return;
    _motion = motion;
    _timer?.cancel();
    _timer = null;
    if (_ticker.isActive) _ticker.stop();
    if (motion) {
      _ticker.start();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed.value += const Duration(seconds: 1);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  static List<int> _parts(int secs) => [
    secs ~/ 86400,
    secs % 86400 ~/ 3600,
    secs % 3600 ~/ 60,
    secs % 60,
  ];

  CountdownSnap _snap(Duration elapsed) {
    final now = _t0.add(elapsed);
    final starts = now.isBefore(widget.startsAt);
    final target = starts ? widget.startsAt : widget.endsAt;
    final remMs = target.difference(now).inMilliseconds;
    final total = widget.endsAt.difference(widget.startsAt).inMilliseconds;
    final ended = !starts && remMs <= 0;
    final secs = ended ? 0 : (remMs / 1000).ceil();
    final into = remMs % 1000 == 0 ? 0 : 1000 - remMs % 1000;
    return CountdownSnap(
      cur: _parts(secs),
      prev: _parts(ended ? 0 : secs + 1),
      t: _motion ? (into / 450).clamp(0.0, 1.0) : 1,
      loop: elapsed.inMicroseconds / 1e6,
      fractionLeft: starts
          ? 1
          : total <= 0
          ? 0
          : (remMs / total).clamp(0.0, 1.0),
      urgent: !starts && !ended && remMs <= 3600 * 1000,
      ended: ended,
      starts: starts,
      motion: _motion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RepaintBoundary(
      key: EventHeroCountdown.key0,
      child: ValueListenableBuilder<Duration>(
        valueListenable: _elapsed,
        builder: (context, e, _) {
          final s = _snap(e);
          // The unit names agree with their numbers (Arabic plurals).
          final labels = [
            l10n.eventsUnitDays(s.cur[0]),
            l10n.eventsUnitHours(s.cur[1]),
            l10n.eventsUnitMinutes(s.cur[2]),
            l10n.eventsUnitSeconds(s.cur[3]),
          ];
          final heading = s.ended
              ? l10n.eventsCountdownEnded
              : s.urgent
              ? l10n.eventsLastHour
              : (s.starts
                        ? l10n.eventsCountdownStarts('')
                        : l10n.eventsCountdownEnds(''))
                    .trim();
          return Semantics(
            liveRegion: false,
            label: s.ended
                ? heading
                : '$heading ${s.cur[0]} ${labels[0]} ${s.cur[1]} ${labels[1]} '
                      '${s.cur[2]} ${labels[2]}',
            excludeSemantics: true,
            child: switch (widget.style) {
              HeroCountdownStyle.flip => _Flip(s, heading, labels),
              HeroCountdownStyle.ring => _Ring(s, heading, labels),
              HeroCountdownStyle.coins => _Coins(s, heading, labels),
              HeroCountdownStyle.neon => _Neon(s, heading, labels),
              HeroCountdownStyle.ribbon => _Ribbon(s, heading, labels),
            },
          );
        },
      ),
    );
  }
}

// ---- shared bits -------------------------------------------------------

TextStyle _digitStyle(double size, Color color, {List<Shadow>? shadows}) =>
    TextStyle(
      fontFamily: KFonts.latin,
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w800,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: shadows,
    );

TextStyle _labelStyle(BuildContext context, Color color, {double? size}) =>
    context.textStyles.label.copyWith(
      color: color,
      fontSize: size,
      height: 1.2,
      fontWeight: FontWeight.w700,
      shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
    );

/// The heading over a countdown («تنتهي بعد» / «الساعة الأخيرة!»).
class _Heading extends StatelessWidget {
  const new(this.text, this.s);

  final String text;
  final CountdownSnap s;
  static const Color color = _goldLight;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: context.textStyles.title.copyWith(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: s.urgent ? Color.lerp(_goldLight, _redLight, s.pulse) : color,
      shadows: const [Shadow(color: Color(0xE6000000), blurRadius: 6)],
    ),
  );
}

/// The «انتهت الفعالية» plate shown by every style when the event is over.
class _EndedPlate extends StatelessWidget {
  const new(this.text);

  final String text;
  static const double height = 84;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_wineMid, _wine],
      ),
      borderRadius: BorderRadius.circular(KRadius.lg),
      border: Border.all(color: _gold.withValues(alpha: .7), width: 1.5),
    ),
    child: Text(
      text,
      style: context.textStyles.headline.copyWith(
        color: _goldLight,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Four units in a left-to-right row with separators between them.
class _UnitRow extends StatelessWidget {
  const new({required this.unit, required this.separator});

  final Widget Function(int i) unit;
  final Widget separator;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 4; i++) ...[if (i > 0) separator, unit(i)],
      ],
    ),
  );
}

/// A labelled unit: [child] over its unit name.
class _Labelled extends StatelessWidget {
  const new({
    required this.label,
    required this.child,
    this.color = _goldLight,
  });

  final String label;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      child,
      const SizedBox(height: 6),
      Directionality(
        textDirection: Directionality.of(context),
        child: Text(label, style: _labelStyle(context, color, size: 12)),
      ),
    ],
  );
}

// ---- 1. Flip clock -----------------------------------------------------

class _Flip extends StatelessWidget {
  const new(this.s, this.heading, this.labels);

  final CountdownSnap s;
  final String heading;
  final List<String> labels;

  static const double w = 72;
  static const double h = 84;

  @override
  Widget build(BuildContext context) {
    if (s.ended) return _EndedPlate(heading);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Heading(heading, s),
        const SizedBox(height: KSpacing.sm),
        _UnitRow(
          separator: SizedBox(
            width: 14,
            height: h,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: s.urgent ? _redLight : _gold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          unit: (i) => _Labelled(
            label: labels[i],
            child: _FlipCard(
              cur: CountdownSnap.two(s.cur[i]),
              prev: CountdownSnap.two(s.prev[i]),
              t: s.changed(i) ? s.t : 1,
              urgent: s.urgent,
              pulse: s.pulse,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlipCard extends StatelessWidget {
  const new({
    required this.cur,
    required this.prev,
    required this.t,
    required this.urgent,
    required this.pulse,
  });

  final String cur;
  final String prev;
  final double t;
  final bool urgent;
  final double pulse;

  Widget _face(String text, {double shade = 0}) => Container(
    width: _Flip.w,
    height: _Flip.h,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(const Color(0xFF731420), Colors.black, shade)!,
          Color.lerp(const Color(0xFF4A0A12), Colors.black, shade)!,
          Color.lerp(const Color(0xFF3A060C), Colors.black, shade)!,
          Color.lerp(const Color(0xFF26040A), Colors.black, shade)!,
        ],
        stops: const [0, .499, .501, 1],
      ),
      borderRadius: BorderRadius.circular(KRadius.md),
    ),
    child: Text(
      text,
      style: _digitStyle(
        46,
        Color.lerp(_goldLight, const Color(0xFF6E5520), shade)!,
        shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 2))],
      ),
    ),
  );

  Widget _half(Widget face, {required bool top}) => ClipRect(
    child: Align(
      alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
      heightFactor: .5,
      child: face,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rim = urgent ? Color.lerp(_red, _redLight, pulse)! : _gold;
    Widget body;
    if (t >= 1) {
      body = _face(cur);
    } else {
      final first = t < .5;
      final angle = first ? t * 2 * (math.pi / 2) : (1 - t) * 2 * (math.pi / 2);
      final leaf = Transform(
        alignment: first ? Alignment.bottomCenter : Alignment.topCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .004)
          ..rotateX(first ? -angle : angle),
        child: first
            ? _half(_face(prev, shade: t), top: true)
            : _half(_face(cur, shade: (1 - t) * .6), top: false),
      );
      body = Stack(
        children: [
          // Behind: the new top half and the old bottom half.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _half(_face(cur), top: true),
              _half(_face(prev), top: false),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: first ? 0 : _Flip.h / 2,
            height: _Flip.h / 2,
            child: leaf,
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: urgent
              ? [rim, KBrandColors.red700]
              : const [_goldLight, _gold, _goldDeep],
        ),
        borderRadius: BorderRadius.circular(KRadius.md + 2),
        boxShadow: [
          BoxShadow(
            color: (urgent ? _red : Colors.black).withValues(
              alpha: urgent ? .35 + .4 * pulse : .5,
            ),
            blurRadius: urgent ? 10 + 8 * pulse : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          body,
          // Hinge with side pins.
          Container(height: 2, width: _Flip.w, color: const Color(0xCC12020A)),
          Positioned(
            left: -1,
            child: Container(width: 4, height: 10, color: _goldDeep),
          ),
          Positioned(
            right: -1,
            child: Container(width: 4, height: 10, color: _goldDeep),
          ),
        ],
      ),
    );
  }
}

// ---- 2. Glowing ring ---------------------------------------------------

class _Ring extends StatelessWidget {
  const new(this.s, this.heading, this.labels);

  final CountdownSnap s;
  final String heading;
  final List<String> labels;

  static const double d = 160;

  @override
  Widget build(BuildContext context) {
    final digits = s.urgent
        ? Color.lerp(Colors.white, const Color(0xFFFFC2C6), s.pulse)!
        : _goldLight;
    const two = CountdownSnap.two;
    // Days in the centre; under a day, the biggest two units move there.
    final String big;
    final String unit;
    String? small;
    if (s.cur[0] > 0) {
      big = two(s.cur[0]);
      unit = labels[0];
      small = '${two(s.cur[1])}:${two(s.cur[2])}:${two(s.cur[3])}';
    } else if (s.cur[1] > 0) {
      big = '${two(s.cur[1])}:${two(s.cur[2])}';
      unit = '${labels[1]} : ${labels[2]}';
      small = two(s.cur[3]);
    } else {
      big = '${two(s.cur[2])}:${two(s.cur[3])}';
      unit = '${labels[2]} : ${labels[3]}';
    }
    final bigChanged = s.cur[0] > 0 ? s.changed(0) : s.changed(3);
    return Center(
      child: SizedBox.square(
        dimension: d,
        child: CustomPaint(
          painter: _RingPainter(s),
          child: s.ended
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Text(
                      heading,
                      textAlign: TextAlign.center,
                      style: context.textStyles.title.copyWith(
                        color: _goldLight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      heading,
                      style: _labelStyle(
                        context,
                        s.urgent ? const Color(0xFFFFB3B8) : _goldLight,
                        size: 12,
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Transform.scale(
                        scale: bigChanged && s.cur[0] > 0
                            ? 1 + .12 * (1 - s.t)
                            : 1,
                        child: Text(
                          big,
                          style: _digitStyle(
                            big.length > 2 ? 36 : 52,
                            digits,
                            shadows: [
                              Shadow(
                                color: (s.urgent ? _red : _gold).withValues(
                                  alpha: .7,
                                ),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit,
                      style: _labelStyle(context, _goldLight, size: 12),
                    ),
                    if (small != null) ...[
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          small,
                          style: _digitStyle(17, Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  new(this.s);

  final CountdownSnap s;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 16;
    const stroke = 10.0;
    final rect = Rect.fromCircle(center: c, radius: r);
    // Disc behind the numbers.
    canvas
      ..drawCircle(
        c,
        r - stroke / 2 - 1,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xF2420810), Color(0xF21A0306)],
          ).createShader(rect),
      )
      // Track.
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0xFF3A070C),
      );
    // Second ticks around the outside; the current second is lit.
    for (var i = 0; i < 60; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 60;
      final lit = !s.ended && i == (60 - s.cur[3]) % 60;
      final o = c + Offset(math.cos(a), math.sin(a)) * (r + stroke / 2 + 4);
      final o2 =
          c +
          Offset(math.cos(a), math.sin(a)) *
              (r + stroke / 2 + (i % 5 == 0 ? 9 : 7));
      canvas.drawLine(
        o,
        o2,
        Paint()
          ..strokeWidth = lit ? 3 : 1.4
          ..strokeCap = StrokeCap.round
          ..color = lit
              ? (s.urgent ? _redLight : Colors.white)
              : _gold.withValues(alpha: i % 5 == 0 ? .7 : .35),
      );
    }
    if (s.ended) return;
    final sweep = math.pi * 2 * s.fractionLeft;
    final main = s.urgent ? _red : _gold;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 6
      ..strokeCap = StrokeCap.round
      ..color = main.withValues(alpha: s.urgent ? .25 + .45 * s.pulse : .35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas
      ..drawArc(rect, -math.pi / 2, sweep, false, glow)
      ..drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            transform: const GradientRotation(-math.pi / 2),
            colors: s.urgent
                ? const [KBrandColors.red700, _red, _redLight]
                : const [_goldDeep, _gold, _goldLight],
          ).createShader(rect),
      );
    // Shimmer: a bright short arc that runs along the progress (2.4 s).
    if (s.motion && sweep > .3) {
      final head = (s.loop / 2.4 % 1) * sweep;
      canvas.drawArc(
        rect,
        -math.pi / 2 + math.max(0, head - .35),
        math.min(.35, head),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke - 4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: .75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // The head knob.
    final a = -math.pi / 2 + sweep;
    final k = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas
      ..drawCircle(k, 7, Paint()..color = Colors.white)
      ..drawCircle(k, 4.5, Paint()..color = main);
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}

// ---- 3. Gold coin dials -------------------------------------------------

class _Coins extends StatelessWidget {
  const new(this.s, this.heading, this.labels);

  final CountdownSnap s;
  final String heading;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (s.ended) return _EndedPlate(heading);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Heading(heading, s),
        const SizedBox(height: KSpacing.sm),
        _UnitRow(
          separator: const SizedBox(width: 12),
          unit: (i) {
            final changing = s.changed(i) && s.t < 1;
            final spin = changing ? s.t : 1.0;
            final showPrev = changing && spin < .5;
            final sx = changing ? math.cos(math.pi * spin).abs() : 1.0;
            return _Labelled(
              label: labels[i],
              child: SizedBox.square(
                dimension: 78,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    changing ? -6 * math.sin(math.pi * spin) : 0,
                  ),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(math.max(.06, sx), 1, 1),
                    child: CustomPaint(
                      painter: _CoinPainter(
                        urgent: s.urgent && i == 3,
                        pulse: s.pulse,
                        edge: changing ? 1 - sx : 0,
                        shine: changing ? spin : -1,
                      ),
                      child: Center(
                        child: Text(
                          CountdownSnap.two(showPrev ? s.prev[i] : s.cur[i]),
                          style: _digitStyle(
                            32,
                            const Color(0xFF4A0A0F),
                            shadows: const [
                              Shadow(
                                color: Color(0x80FFF4C8),
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CoinPainter extends CustomPainter {
  new({
    required this.urgent,
    required this.pulse,
    required this.edge,
    required this.shine,
  });

  final bool urgent;
  final double pulse;

  /// 0 face-on → 1 edge-on (darkens the face while it spins).
  final double edge;

  /// Position of the light sweep (−1 = none).
  final double shine;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c + const Offset(0, 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    if (urgent) {
      canvas.drawCircle(
        c,
        r + 2,
        Paint()
          ..color = _red.withValues(alpha: .35 + .5 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * pulse),
      );
    }
    // Rim with reeded edge.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, _goldDeep, Color(0xFF8A5A14)],
        ).createShader(rect),
    );
    final notch = Paint()
      ..color = const Color(0x667A4A0C)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 48; i++) {
      final a = i * math.pi * 2 / 48;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r - 4), c + d * (r - .5), notch);
    }
    // Face.
    final face = r - 6;
    canvas
      ..drawCircle(
        c,
        face,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.35, -.4),
            radius: 1.1,
            colors: [
              Color.lerp(const Color(0xFFFFF4C8), Colors.black, edge * .5)!,
              Color.lerp(_gold, Colors.black, edge * .5)!,
              Color.lerp(const Color(0xFFD69B2E), Colors.black, edge * .5)!,
            ],
            stops: const [0, .55, 1],
          ).createShader(Rect.fromCircle(center: c, radius: face)),
      )
      ..drawCircle(
        c,
        face - 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x809A6416),
      );
    if (shine >= 0) {
      canvas
        ..save()
        ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: face)));
      final x = -r + shine * 4 * r;
      canvas
        ..drawRect(
          Rect.fromLTWH(c.dx + x - 6, c.dy - r, 12, 2 * r),
          Paint()
            ..color = Colors.white.withValues(alpha: .55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_CoinPainter old) =>
      old.edge != edge ||
      old.shine != shine ||
      old.pulse != pulse ||
      old.urgent != urgent;
}

// ---- 4. Neon digital ---------------------------------------------------

class _Neon extends StatelessWidget {
  const new(this.s, this.heading, this.labels);

  final CountdownSnap s;
  final String heading;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final color = s.urgent ? const Color(0xFFFF3B5C) : const Color(0xFFFFC447);
    return CustomPaint(
      painter: _NeonPanelPainter(
        color: color,
        loop: s.loop,
        motion: s.motion,
        pulse: s.urgent ? s.pulse : 0,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: s.ended
            ? SizedBox(
                height: 96,
                child: Center(
                  child: Text(
                    heading,
                    style: context.textStyles.headline.copyWith(
                      color: const Color(0xFFFFF1D6),
                      shadows: [Shadow(color: color, blurRadius: 12)],
                    ),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    heading,
                    style: _labelStyle(
                      context,
                      const Color(0xFFFFF1D6),
                      size: 14,
                    ).copyWith(shadows: [Shadow(color: color, blurRadius: 8)]),
                  ),
                  const SizedBox(height: 8),
                  _UnitRow(
                    separator: SizedBox(
                      width: 18,
                      height: 52,
                      child: CustomPaint(
                        painter: _ColonPainter(
                          color: color,
                          on: !s.motion || s.loop % 1 < .6,
                        ),
                      ),
                    ),
                    unit: (i) => _Labelled(
                      label: labels[i],
                      color: const Color(0xFFFFE2A8),
                      child: SizedBox(
                        width: 64,
                        height: 52,
                        child: CustomPaint(
                          painter: _SevenSegPainter(
                            text: CountdownSnap.two(s.cur[i]),
                            color: color,
                            flash: s.changed(i) ? 1 - s.t : 0,
                            flicker: s.motion ? _flicker(s.loop) : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// A deterministic, mostly steady flicker (a short dip every ~3.7 s).
  static double _flicker(double t) {
    final p = t % 3.7;
    if (p > 3.55 && p < 3.62) return .55;
    if (p > 3.64 && p < 3.68) return .75;
    return .92 + .08 * math.sin(t * 9.3);
  }
}

class _NeonPanelPainter extends CustomPainter {
  new({
    required this.color,
    required this.loop,
    required this.motion,
    required this.pulse,
  });

  final Color color;
  final double loop;
  final bool motion;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(KRadius.lg + 2),
    );
    canvas
      ..drawRRect(rr, Paint()..color = const Color(0xF20E0306))
      // Scanlines, drifting slowly.
      ..save()
      ..clipRRect(rr);
    final off = motion ? (loop * 10) % 4 : 0.0;
    final line = Paint()..color = const Color(0x0FFFFFFF);
    for (var y = off; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.2), line);
    }
    // A faint reflection band.
    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * .45),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
          ).createShader(Offset.zero & size),
      )
      ..restore()
      // Neon tube border: glow + core.
      ..drawRRect(
        rr.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = color.withValues(alpha: .45 + .4 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * pulse),
      )
      ..drawRRect(
        rr.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Color.lerp(color, Colors.white, .55)!,
      );
  }

  @override
  bool shouldRepaint(_NeonPanelPainter old) =>
      old.loop != loop || old.color != color || old.pulse != pulse;
}

class _ColonPainter extends CustomPainter {
  new({required this.color, required this.on});

  final Color color;
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    for (final y in [size.height * .32, size.height * .68]) {
      final o = Offset(size.width / 2, y);
      if (on) {
        canvas.drawCircle(
          o,
          5,
          Paint()
            ..color = color.withValues(alpha: .6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(
        o,
        3,
        Paint()
          ..color = on
              ? Color.lerp(color, Colors.white, .6)!
              : color.withValues(alpha: .45),
      );
    }
  }

  @override
  bool shouldRepaint(_ColonPainter old) => old.on != on || old.color != color;
}

class _SevenSegPainter extends CustomPainter {
  new({
    required this.text,
    required this.color,
    required this.flash,
    required this.flicker,
  });

  final String text;
  final Color color;
  final double flash;
  final double flicker;

  //  a
  // f b
  //  g
  // e c
  //  d
  static const _map = {
    '0': 'abcdef',
    '1': 'bc',
    '2': 'abged',
    '3': 'abgcd',
    '4': 'fgbc',
    '5': 'afgcd',
    '6': 'afgedc',
    '7': 'abc',
    '8': 'abcdefg',
    '9': 'abcdfg',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cw = (size.width - 8) / 2;
    for (var i = 0; i < text.length; i++) {
      _digit(
        canvas,
        Rect.fromLTWH(i * (cw + 8), 0, cw, size.height),
        _map[text[i]] ?? '',
      );
    }
  }

  void _digit(Canvas canvas, Rect r, String on) {
    const t = 5.5;
    final skew = Matrix4.identity()..setEntry(0, 1, -.08);
    Path seg(String s) {
      final w = r.width;
      final h = r.height;
      final x = r.left;
      final y = r.top;
      final hm = h / 2;
      Rect rr;
      switch (s) {
        case 'a':
          rr = Rect.fromLTWH(x + t * .7, y, w - t * 1.4, t);
        case 'd':
          rr = Rect.fromLTWH(x + t * .7, y + h - t, w - t * 1.4, t);
        case 'g':
          rr = Rect.fromLTWH(x + t * .7, y + hm - t / 2, w - t * 1.4, t);
        case 'f':
          rr = Rect.fromLTWH(x, y + t * .7, t, hm - t * 1.1);
        case 'b':
          rr = Rect.fromLTWH(x + w - t, y + t * .7, t, hm - t * 1.1);
        case 'e':
          rr = Rect.fromLTWH(x, y + hm + t * .4, t, hm - t * 1.1);
        default:
          rr = Rect.fromLTWH(x + w - t, y + hm + t * .4, t, hm - t * 1.1);
      }
      return Path()
        ..addRRect(RRect.fromRectAndRadius(rr, const Radius.circular(t / 2)));
    }

    canvas
      ..save()
      ..translate(r.center.dx, r.center.dy)
      ..transform(skew.storage)
      ..translate(-r.center.dx, -r.center.dy);
    final glow = Paint()
      ..color = color.withValues(alpha: (.55 + .35 * flash) * flicker)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 4 * flash);
    final core = Paint()
      ..color = Color.lerp(
        color,
        Colors.white,
        .62 + .3 * flash,
      )!.withValues(alpha: .4 + .6 * flicker);
    final off = Paint()..color = color.withValues(alpha: .09);
    for (final s in 'abcdefg'.split('')) {
      final p = seg(s);
      if (on.contains(s)) {
        canvas
          ..drawPath(p, glow)
          ..drawPath(p, core);
      } else {
        canvas.drawPath(p, off);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SevenSegPainter old) =>
      old.text != text ||
      old.flash != flash ||
      old.flicker != flicker ||
      old.color != color;
}

// ---- 5. Ribbon banner with odometer digits -------------------------------

class _Ribbon extends StatelessWidget {
  const new(this.s, this.heading, this.labels);

  final CountdownSnap s;
  final String heading;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _RibbonPainter(s),
        child: Column(
          children: [
            // The heading plaque on top of the band.
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_goldLight, _gold, _goldDeep],
                ),
                borderRadius: BorderRadius.circular(KRadius.pill),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                heading,
                style: context.textStyles.label.copyWith(
                  color: s.urgent ? KBrandColors.red700 : _wine,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (s.ended)
              Expanded(
                child: Center(
                  child: Text(
                    heading,
                    style: context.textStyles.headline.copyWith(
                      color: _goldLight,
                    ),
                  ),
                ),
              )
            else
              _UnitRow(
                separator: SizedBox(
                  width: 16,
                  height: 46,
                  child: Center(
                    child: Text(
                      ':',
                      style: _digitStyle(30, _gold.withValues(alpha: .9)),
                    ),
                  ),
                ),
                unit: (i) => _Labelled(
                  label: labels[i],
                  child: _Odometer(
                    cur: CountdownSnap.two(s.cur[i]),
                    prev: CountdownSnap.two(s.prev[i]),
                    t: s.changed(i) ? s.t : 1,
                    urgent: s.urgent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Odometer extends StatelessWidget {
  const new({
    required this.cur,
    required this.prev,
    required this.t,
    required this.urgent,
  });

  final String cur;
  final String prev;
  final double t;
  final bool urgent;

  static const double cellW = 26;
  static const double cellH = 46;

  @override
  Widget build(BuildContext context) {
    final style = _digitStyle(
      36,
      urgent ? Colors.white : _goldLight,
      shadows: const [
        Shadow(color: Color(0xB3000000), offset: Offset(0, 2), blurRadius: 2),
      ],
    );
    final e = Curves.easeOutBack.transform(t.clamp(0, 1));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0205), Color(0xFF3D070D), Color(0xFF1A0205)],
        ),
        borderRadius: BorderRadius.circular(KRadius.sm),
        border: Border.all(color: _goldDeep),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < 2; k++)
            SizedBox(
              width: cellW,
              height: cellH,
              child: ClipRect(
                child: cur[k] == prev[k] || t >= 1
                    ? Center(child: Text(cur[k], style: style))
                    : Stack(
                        children: [
                          // Counting down: digits roll downward.
                          Positioned(
                            left: 0,
                            right: 0,
                            top: cellH * e,
                            height: cellH,
                            child: Center(child: Text(prev[k], style: style)),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: -cellH + cellH * e,
                            height: cellH,
                            child: Center(child: Text(cur[k], style: style)),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  new(this.s);

  final CountdownSnap s;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 16.0;
    final bandH = size.height - top - 6;
    final w = size.width;
    const tail = 22.0;
    final base = s.urgent
        ? [
            Color.lerp(const Color(0xFF8A050C), _red, s.pulse * .6)!,
            const Color(0xFF5A030A),
          ]
        : const [Color(0xFF7A0E18), Color(0xFF3A060C)];
    // Tails (behind, darker, notched).
    for (final left in [true, false]) {
      final x0 = left ? 0.0 : w;
      final dir = left ? 1.0 : -1.0;
      final p = Path()
        ..moveTo(x0, top + 14)
        ..lineTo(x0 + dir * (tail + 18), top + 14)
        ..lineTo(x0 + dir * (tail + 18), top + bandH + 10)
        ..lineTo(x0, top + bandH + 10)
        ..lineTo(x0 + dir * 12, top + 14 + (bandH - 4) / 2)
        ..close();
      canvas
        ..drawPath(p, Paint()..color = const Color(0xFF2A0408))
        ..drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = _goldDeep,
        );
    }
    // Main band.
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(tail, top, w - tail * 2, bandH),
      const Radius.circular(10),
    );
    canvas
      ..drawRRect(
        band.shift(const Offset(0, 4)),
        Paint()
          ..color = Colors.black.withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..drawRRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: base,
          ).createShader(band.outerRect),
      );
    // Gold edges.
    final edge = Paint()
      ..shader = const LinearGradient(
        colors: [_goldDeep, _goldLight, _gold, _goldLight, _goldDeep],
      ).createShader(band.outerRect);
    canvas
      ..drawRRect(
        band,
        edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      )
      ..drawRRect(
        band.deflate(5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = _gold.withValues(alpha: .45),
      );
    if (!s.motion) return;
    // Sparkles twinkling along the band edges.
    final rnd = math.Random(7);
    for (var i = 0; i < 16; i++) {
      final onTop = i.isEven;
      final x = tail + 8 + rnd.nextDouble() * (w - tail * 2 - 16);
      final y = (onTop ? top : top + bandH) + (rnd.nextDouble() - .5) * 14;
      final seed = rnd.nextDouble();
      final a = math.max<double>(
        0,
        math.sin(2 * math.pi * (s.loop / 1.8 + seed)),
      );
      if (a <= .05) continue;
      final r = (3 + rnd.nextDouble() * 4) * a;
      final col = s.urgent ? const Color(0xFFFFC2C6) : const Color(0xFFFFF4CF);
      _star(canvas, Offset(x, y), r, col.withValues(alpha: a));
    }
  }

  static void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas
      ..drawCircle(
        c,
        r * .9,
        Paint()
          ..color = color.withValues(alpha: color.a * .4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => true;
}
