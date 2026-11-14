// D322: the app's bottom navigation bar — the OWNER'S OWN DESIGN (his
// `kabso_nav_bar.dart` v3, supplied 2026-11-08; his drawing, icons,
// animations, sizes and colours). Five tabs, start → end (Arabic: right →
// left): البث · الحفلة · اللحظات · الرسائل · أنا; no centre button. Every
// icon is drawn with a CustomPainter and animates on its own tap:
//
// - البث: the house jumps, the play pulses, broadcast waves ripple out.
// - الحفلة: the popper tilts and bursts confetti.
// - اللحظات: the cards fan out and stars burst.
// - الرسائل: the bubble squashes, the dots type, a small bubble floats up.
// - أنا: the face bounces, winks, and a heart floats up.
//
// Adapted to Kabso's app, the drawing unchanged:
// - labels from gen-l10n (the shell passes them; overridable);
// - the order follows the ambient [Directionality] (his file forced RTL:
//   English reads left → right);
// - colours from the design tokens, light and dark (his white / greys
//   are the light palette's surface / greys; see [_NavColors]); the
//   confetti, stars and blush stay his art colours;
// - `withOpacity` → `withValues(alpha:)`;
// - the labels use the app's font (his bare `TextStyle` would fall back to
//   the platform font) and their text scale is capped so the 64 pt bar
//   never overflows;
// - a re-tap replays the animation (his) and also calls [onReselect] (the
//   shell returns that tab to its first page, as before);
// - semantics: one button per tab with its label, selected state and the
//   unread count; haptics kept; reduced motion: no animation.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// What a [KabsoNavBar] tab draws, in the bar's order.
enum KabsoNavIcon { live, party, moments, messages, me }

/// The app's bottom navigation (D322, the owner's design).
class KabsoNavBar extends StatefulWidget {
  const new({
    required this.currentIndex,
    required this.onTap,
    required this.labels,
    super.key,
    this.onReselect,
    this.unreadMessages = 0,
    this.unreadLabel,
    this.momentsDot = false,
    this.momentsDotLabel,
    this.itemKeys,
  }) : assert(labels.length == 5, 'one label per tab'),
       assert(itemKeys == null || itemKeys.length == 5, 'one key per tab');

  /// Index of the selected tab (0 live · 1 party · 2 moments · 3 messages
  /// · 4 me).
  final int currentIndex;

  /// A tap on another tab.
  final ValueChanged<int> onTap;

  /// A tap on the selected tab (after its animation replays).
  final ValueChanged<int>? onReselect;

  /// The five visible labels, in [KabsoNavIcon] order.
  final List<String> labels;

  /// The Messages badge (hidden at 0, "99+" above 99).
  final int unreadMessages;

  /// What a screen reader says for the badge (e.g. "7 unread messages").
  final String? unreadLabel;

  /// A small dot on Moments (new stories); hidden while it is selected.
  final bool momentsDot;
  final String? momentsDotLabel;

  /// Keys of the five tabs' semantics nodes (the shell's `nav.*` keys).
  final List<Key>? itemKeys;

  /// The owner's sizes.
  static const double barHeight = KSizes.bottomNavHeight;
  static const double iconBox = 30;

  /// The labels scale at most this much (the bar has a fixed height).
  static const double maxTextScale = 1.15;

  /// The owner's animation length.
  static const Duration duration = Duration(milliseconds: 750);

  static const Key badgeKey = Key('navBar.badge');
  static const Key dotKey = Key('navBar.dot');

  @override
  State<KabsoNavBar> createState() => KabsoNavBarState();
}

class KabsoNavBarState extends State<KabsoNavBar>
    with TickerProviderStateMixin {
  static const List<KabsoNavIcon> _icons = KabsoNavIcon.values;
  late final List<AnimationController> _c = List.generate(
    _icons.length,
    (_) => AnimationController(
      vsync: this,
      duration: KabsoNavBar.duration,
      value: 1,
    ),
  );

  /// Whether tab [i]'s animation is playing (tests).
  @visibleForTesting
  bool isAnimating(int i) => _c[i].isAnimating;

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didUpdateWidget(covariant KabsoNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _play(widget.currentIndex);
    }
  }

  void _play(int i) {
    if (_reduce) {
      _c[i].value = 1;
      return;
    }
    _c[i].forward(from: 0);
  }

  void _tap(int i) {
    unawaited(HapticFeedback.selectionClick());
    if (i == widget.currentIndex) {
      _play(i); // re-tap replays the animation
      widget.onReselect?.call(i);
    } else {
      widget.onTap(i);
    }
  }

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _NavColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: KabsoNavBar.barHeight + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: KabsoNavBar.maxTextScale,
        child: Row(
          children: [
            for (var i = 0; i < _icons.length; i++)
              Expanded(child: _button(i, colors)),
          ],
        ),
      ),
    );
  }

  Widget _button(int i, _NavColors colors) {
    final active = i == widget.currentIndex;
    final kind = _icons[i];
    final badge =
        kind == KabsoNavIcon.messages &&
        widget.unreadMessages > 0 &&
        widget.unreadLabel != null;
    final dot =
        kind == KabsoNavIcon.moments &&
        widget.momentsDot &&
        !active &&
        widget.momentsDotLabel != null;
    final label = [
      widget.labels[i],
      if (badge) widget.unreadLabel!,
      if (dot) widget.momentsDotLabel!,
    ].join(', ');
    return Semantics(
      key: widget.itemKeys?[i],
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      onTap: () => _tap(i),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(i),
        child: AnimatedBuilder(
          animation: _c[i],
          builder: (context, _) => _item(i, colors),
        ),
      ),
    );
  }

  Widget _item(int i, _NavColors colors) {
    final kind = _icons[i];
    final active = i == widget.currentIndex;
    final p = active ? _c[i].value : 1.0;

    // pop: 0.8 → 1.14 → elastic back to 1
    final scale = !active
        ? 1.0
        : (p < .25
              ? _lerp(.8, 1.14, _easeOut(p / .25))
              : _lerp(1.14, 1, Curves.elasticOut.transform((p - .25) / .75)));
    final tilt = active && kind == KabsoNavIcon.party
        ? -14 * _bump(p, 0, .45) * math.pi / 180
        : 0.0;
    final size = kind == KabsoNavIcon.me ? 30.0 : 28.0;

    Widget icon = CustomPaint(
      size: Size.square(size),
      painter: _KabsoIconPainter(
        kind: kind,
        active: active,
        p: p,
        colors: colors,
      ),
    );
    icon = Transform.rotate(
      angle: tilt,
      alignment: const Alignment(-.4, .7),
      child: Transform.scale(scale: scale, child: icon),
    );
    if (kind == KabsoNavIcon.messages && widget.unreadMessages > 0) {
      icon = Badge(
        label: Text(
          widget.unreadMessages > 99 ? '99+' : '${widget.unreadMessages}',
          key: KabsoNavBar.badgeKey,
        ),
        backgroundColor: colors.red,
        textColor: colors.onRed,
        child: icon,
      );
    } else if (kind == KabsoNavIcon.moments && widget.momentsDot && !active) {
      icon = Badge(
        key: KabsoNavBar.dotKey,
        backgroundColor: colors.red,
        child: icon,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: KabsoNavBar.iconBox,
          child: Center(child: icon),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: KMotion.of(context, const Duration(milliseconds: 200)),
          style: context.textStyles.caption.copyWith(
            fontSize: 13,
            height: 1.2,
            color: active ? colors.selectedLabel : colors.label,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.labels[i], maxLines: 1),
          ),
        ),
      ],
    );
  }
}

/// The owner's colours mapped to the palette (light ≈ his values):
///
/// | his               | token                                      |
/// |-------------------|--------------------------------------------|
/// | white bar / fills | `surfaceRaised` (#FFF / dark #1F1F25)      |
/// | #EDEDF0 hairline  | light `surfaceOverlay` #ECECF0, dark `border` |
/// | #C8101A red       | `primary` (#C8080F / dark #E50914)         |
/// | #E8333D sheen     | `red500` / dark `red400`                   |
/// | #1C1C1E ink       | `textPrimary`                              |
/// | #7A7A82 icons     | `borderStrong` (≥ 3:1 on the bar)          |
/// | #55555C labels    | `textSecondary` (≥ 4.5:1)                  |
/// | red label         | `primaryText` (dark #FF3B47, ≥ 4.5:1)      |
/// | white on red      | `onPrimary`                                |
@immutable
class _NavColors {
  const new({
    required this.surface,
    required this.hairline,
    required this.red,
    required this.redHi,
    required this.ink,
    required this.idle,
    required this.label,
    required this.selectedLabel,
    required this.onRed,
  });

  factory of(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _NavColors(
      surface: p.surfaceRaised,
      hairline: dark ? p.border : p.surfaceOverlay,
      red: p.primary,
      redHi: dark ? KBrandColors.red400 : KBrandColors.red500,
      ink: p.textPrimary,
      idle: p.borderStrong,
      label: p.textSecondary,
      selectedLabel: p.primaryText,
      onRed: p.onPrimary,
    );
  }

  final Color surface;
  final Color hairline;
  final Color red;
  final Color redHi;
  final Color ink;
  final Color idle;
  final Color label;
  final Color selectedLabel;
  final Color onRed;

  @override
  bool operator ==(Object other) =>
      other is _NavColors &&
      other.surface == surface &&
      other.red == red &&
      other.ink == ink &&
      other.idle == idle &&
      other.onRed == onRed;

  @override
  int get hashCode => Object.hash(surface, red, ink, idle, onRed);
}

// ─────────────────────────── helpers ───────────────────────────
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _easeOut(double u) => 1 - math.pow(1 - u, 3).toDouble();
double _bump(double t, double a, double b) =>
    (t <= a || t >= b) ? 0 : math.sin(math.pi * (t - a) / (b - a));

// ─────────────────────────── icons ───────────────────────────
// All drawn in a 28×28 design box (scaled to the widget size). p = 0..1
// since the tap (1 = at rest).
class _KabsoIconPainter extends CustomPainter {
  new({
    required this.kind,
    required this.active,
    required this.p,
    required this.colors,
  });
  final KabsoNavIcon kind;
  final bool active;
  final double p;
  final _NavColors colors;

  // The owner's art colours (confetti, stars).
  static const _gold = Color(0xFFFFC107);
  static const List<Color> _confetti = [
    _gold,
    Color(0xFFC8101A),
    Color(0xFF2BB673),
    Color(0xFF3D8BFF),
    Color(0xFFFF6FA8),
    _gold,
  ];
  static const _blush = Color(0xFFFF9AA2);

  Color get red => colors.red;
  Color get grey => colors.idle;

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..color = c
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  Paint _fill(Color c) => Paint()..color = c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 28);
    switch (kind) {
      case KabsoNavIcon.live:
        _live(canvas);
      case KabsoNavIcon.party:
        _party(canvas);
      case KabsoNavIcon.moments:
        _moments(canvas);
      case KabsoNavIcon.messages:
        _messages(canvas);
      case KabsoNavIcon.me:
        _me(canvas);
    }
    canvas.restore();
  }

  // ── البث: house jumps, play pulses, broadcast waves ──
  void _live(Canvas c) {
    final s = active ? colors.ink : grey;
    final jump = -3.2 * _bump(p, 0, .35);
    final pl = 1 + .4 * _bump(p, .2, .55);
    final house = Path()
      ..moveTo(5, 11.6)
      ..lineTo(14, 4.6)
      ..lineTo(23, 11.6)
      ..lineTo(23, 22)
      ..arcToPoint(const Offset(21, 24), radius: const Radius.circular(2))
      ..lineTo(7, 24)
      ..arcToPoint(const Offset(5, 22), radius: const Radius.circular(2))
      ..close();

    c
      ..save()
      ..translate(0, jump)
      ..drawPath(house, _fill(colors.surface));
    if (active) {
      c
        ..save()
        ..clipPath(house)
        ..drawPath(
          Path()..addPolygon(const [
            Offset(3, 20.5),
            Offset(25, 5.5),
            Offset(25, 26),
            Offset(3, 26),
          ], true),
          _fill(red),
        )
        ..drawPath(
          Path()..addPolygon(const [
            Offset(11, 26),
            Offset(25, 16.5),
            Offset(25, 26),
          ], true),
          _fill(colors.redHi),
        )
        ..restore();
    }
    c
      ..drawPath(house, _stroke(s, 2.4))
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(9.6, 12.6, 2.3, 6.4),
          const Radius.circular(1.1),
        ),
        _fill(s),
      )
      ..save()
      ..translate(16.6, 15.8)
      ..scale(pl)
      ..translate(-16.6, -15.8);
    final play = Path()
      ..addPolygon(const [
        Offset(14.4, 12.4),
        Offset(14.4, 19.2),
        Offset(19.8, 15.8),
      ], true);
    final pc = active ? colors.onRed : s;
    c
      ..drawPath(play, _fill(pc))
      ..drawPath(play, _stroke(pc, .8))
      ..restore()
      ..restore();

    if (active && p < 1) {
      for (var k = 0; k < 3; k++) {
        final q = _c01((p - k * .14) / .6);
        if (q <= 0 || q >= 1) continue;
        final r = 5 + 11 * _easeOut(q);
        c.drawArc(
          Rect.fromCircle(center: const Offset(21.5, 6), radius: r),
          -1.25,
          1.1,
          false,
          _stroke(red.withValues(alpha: (1 - q) * .9), 2),
        );
      }
    }
  }

  // ── الحفلة: confetti burst (tilt is applied by the widget) ──
  void _party(Canvas c) {
    final s = active ? red : grey;
    final cone = Path()
      ..addPolygon(const [
        Offset(5, 23.5),
        Offset(10, 9.5),
        Offset(18.5, 18),
      ], true);
    if (active) c.drawPath(cone, _fill(s));
    c
      ..drawPath(cone, _stroke(s, 2.2))
      ..drawLine(
        const Offset(7.4, 16.7),
        const Offset(11.6, 21),
        _stroke(active ? colors.onRed : s, 2),
      );
    final st = _stroke(s, 2.2);
    c
      ..drawLine(const Offset(16.5, 3.5), const Offset(16.5, 7), st)
      ..drawLine(const Offset(21.5, 6.5), const Offset(18.9, 9.1), st)
      ..drawLine(const Offset(24.5, 12), const Offset(21, 12), st);

    if (active && p < 1) {
      for (var i = 0; i < 9; i++) {
        final ang = -1.9 + i * .32;
        final d = 6 + 22 * _easeOut(_c01(p * 1.6));
        final x = 19 + math.cos(ang) * d;
        final y = 9 + math.sin(ang) * d + 18 * p * p;
        final o = 1 - _c01((p - .45) / .55);
        final paint = _fill(_confetti[i % 6].withValues(alpha: o));
        if (i.isOdd) {
          c
            ..save()
            ..translate(x, y)
            ..rotate((p * 400 + i * 40) * math.pi / 180)
            ..drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: 2.8, height: 4.8),
                const Radius.circular(.8),
              ),
              paint,
            )
            ..restore();
        } else {
          c.drawCircle(Offset(x, y), 1.7, paint);
        }
      }
    }
  }

  // ── اللحظات: cards fan out, stars burst ──
  void _moments(Canvas c) {
    final s = active ? red : grey;
    final f = _bump(p, 0, .6);
    final r1 = -9 * f;
    final r2 = 9 * f;
    final sp = _bump(p, .2, .8);

    void rotated(double deg, Offset pivot, void Function() draw) {
      c
        ..save()
        ..translate(pivot.dx, pivot.dy)
        ..rotate(deg * math.pi / 180)
        ..translate(-pivot.dx, -pivot.dy);
      draw();
      c.restore();
    }

    rotated(7 + r2, const Offset(16, 13), () {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(9.5, 4.5, 13, 16.5),
          const Radius.circular(3.2),
        ),
        _stroke(s, 2.1),
      );
    });
    rotated(r1, const Offset(11.5, 15.7), () {
      final card = RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 7.5, 13, 16.5),
        const Radius.circular(3.2),
      );
      c
        ..drawRRect(card, _fill(active ? s : colors.surface))
        ..drawRRect(card, _stroke(s, 2.2));
      final play = Path()
        ..addPolygon(const [
          Offset(9.4, 12.2),
          Offset(9.4, 19.2),
          Offset(15, 15.7),
        ], true);
      final pc = active ? colors.onRed : s;
      c
        ..drawPath(play, _fill(pc))
        ..drawPath(play, _stroke(pc, 1));
    });
    _star(c, const Offset(24.5, 4.4), 2.6 * (1 + 1.1 * sp), _fill(s));

    if (active && p < 1) {
      const dirs = [
        [-1.0, -.6, .9],
        [-.2, -1.0, .7],
        [.7, -.9, .6],
        [1.0, .1, .8],
      ];
      for (var i = 0; i < dirs.length; i++) {
        final q = _c01((p - .1 - i * .06) / .6);
        if (q <= 0 || q >= 1) continue;
        final d = 6 + 12 * _easeOut(q);
        final at = Offset(14 + dirs[i][0] * d, 12 + dirs[i][1] * d);
        c
          ..save()
          ..translate(at.dx, at.dy)
          ..rotate(q * math.pi / 2);
        _star(
          c,
          Offset.zero,
          3.4 * dirs[i][2] * math.sin(math.pi * q),
          _fill(i.isOdd ? _gold : red),
        );
        c.restore();
      }
    }
  }

  // ── الرسائل: squash pop, typing dots, small bubble floats up ──
  void _messages(Canvas c) {
    final s = active ? red : grey;
    final sq = _bump(p, 0, .35);
    final bubble = Path()
      ..moveTo(14, 3.8)
      ..cubicTo(19.9, 3.8, 24.2, 7.9, 24.2, 13.1)
      ..cubicTo(24.2, 15.5, 23.3, 17.6, 21.8, 19.2)
      ..lineTo(23.1, 23.4)
      ..lineTo(18.5, 21.5)
      ..cubicTo(17.1, 22.1, 15.6, 22.4, 14, 22.4)
      ..cubicTo(8.1, 22.4, 3.8, 18.3, 3.8, 13.1)
      ..cubicTo(3.8, 7.9, 8.1, 3.8, 14, 3.8)
      ..close();
    c
      ..save()
      ..translate(14, 24)
      ..scale(1 + .12 * sq, 1 - .12 * sq)
      ..translate(-14, -24);
    if (active) c.drawPath(bubble, _fill(s));
    c.drawPath(bubble, _stroke(s, 2.2));
    for (var i = 0; i < 3; i++) {
      final dy = -2.6 * _bump(p, .08 + i * .12, .38 + i * .12);
      c.drawCircle(
        Offset(9.5 + i * 4.5, 13.5 + dy),
        1.5,
        _fill(active ? colors.onRed : s),
      );
    }
    c.restore();

    final fq = _c01((p - .15) / .75);
    if (active && p < 1 && fq > 0) {
      c
        ..save()
        ..translate(22 + 3 * math.sin(fq * 6), 4 - 14 * _easeOut(fq))
        ..scale(.6 + .4 * math.sin(math.pi * fq));
      final paint = _fill(red.withValues(alpha: 1 - fq));
      c
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: 7.6, height: 6.4),
          paint,
        )
        ..drawPath(
          Path()..addPolygon(const [
            Offset(-2.6, 1.6),
            Offset(-3.6, 3.8),
            Offset(-.6, 2.8),
          ], true),
          paint,
        )
        ..restore();
    }
  }

  // ── أنا: bounce, wink, heart floats up ──
  void _me(Canvas c) {
    final s = active ? red : grey;
    final ink = active ? colors.onRed : s;
    final wink = _bump(p, .15, .55);
    final sq = 1 + .12 * _bump(p, 0, .35);

    c
      ..save()
      ..translate(14, 14)
      ..scale(sq, 2 - sq)
      ..translate(-14, -14);

    if (active) c.drawCircle(const Offset(14, 14.6), 10.6, _fill(s));
    c
      ..drawCircle(const Offset(14, 14.6), 10.6, _stroke(s, 2.2))
      // hair line + curl
      ..drawPath(
        Path()
          ..moveTo(4.6, 9.6)
          ..cubicTo(7, 6.4, 10.2, 4.8, 14, 4.8)
          ..cubicTo(17.8, 4.8, 21, 6.4, 23.4, 9.6),
        _stroke(s, 2.2),
      );
    final curl = Path()
      ..moveTo(20.5, 6.2)
      ..cubicTo(22.1, 5.3, 23.7, 5.3, 24.8, 6.3)
      ..cubicTo(23.8, 6.5, 22.9, 7, 22.2, 7.7)
      ..close();
    c
      ..drawPath(curl, _fill(s))
      ..drawPath(curl, _stroke(s, 1.4));
    // happy eyes (right one winks)
    final eye = _stroke(ink, 1.9);
    c.drawPath(
      Path()
        ..moveTo(9.2, 13.6)
        ..quadraticBezierTo(10.8, 11.7, 12.4, 13.6),
      eye,
    );
    if (wink > .5) {
      c.drawLine(const Offset(15.6, 13.2), const Offset(18.8, 13.2), eye);
    } else {
      c.drawPath(
        Path()
          ..moveTo(15.6, 13.6)
          ..quadraticBezierTo(17.2, 11.7, 18.8, 13.6),
        eye,
      );
    }
    // blush
    final blush = _fill(_blush.withValues(alpha: active ? .95 : .8));
    c
      ..drawOval(
        Rect.fromCenter(
          center: const Offset(8.4, 17.4),
          width: 3.4,
          height: 2.1,
        ),
        blush,
      )
      ..drawOval(
        Rect.fromCenter(
          center: const Offset(19.6, 17.4),
          width: 3.4,
          height: 2.1,
        ),
        blush,
      );
    // smile
    final mouth = Path()
      ..moveTo(11, 18.2)
      ..quadraticBezierTo(14, 21, 17, 18.2);
    if (active) c.drawPath(Path.from(mouth)..close(), _fill(colors.onRed));
    c
      ..drawPath(mouth, _stroke(ink, 1.9))
      ..restore();

    if (active && p < 1) {
      final q = _c01((p - .2) / .7);
      if (q > 0) {
        c
          ..save()
          ..translate(23 + 2 * math.sin(q * 7), 5 - 13 * _easeOut(q))
          ..scale(.8 + .5 * math.sin(math.pi * q));
        final heart = Path()
          ..moveTo(0, 1.8)
          ..cubicTo(-2.6, -.2, -3.6, -1.3, -3.6, -2.5)
          ..arcToPoint(
            const Offset(0, -3.1),
            radius: const Radius.circular(1.8),
          )
          ..arcToPoint(
            const Offset(3.6, -2.5),
            radius: const Radius.circular(1.8),
          )
          ..cubicTo(3.6, -1.3, 2.6, -.2, 0, 1.8)
          ..close();
        final o = 1 - q * q;
        c
          ..drawPath(heart, _fill(red.withValues(alpha: o)))
          ..drawPath(heart, _stroke(colors.surface.withValues(alpha: o), .7))
          ..restore();
      }
    }
  }

  void _star(Canvas c, Offset ctr, double r, Paint paint) {
    if (r <= .05) return;
    final ri = r * .3;
    final path = Path();
    for (var k = 0; k < 8; k++) {
      final a = -math.pi / 2 + k * math.pi / 4;
      final rr = k.isEven ? r : ri;
      final pt = ctr + Offset(math.cos(a), math.sin(a)) * rr;
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(covariant _KabsoIconPainter o) =>
      o.kind != kind || o.active != active || o.p != p || o.colors != colors;
}
