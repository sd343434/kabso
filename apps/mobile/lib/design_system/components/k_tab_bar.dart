// D130: the owner's animated bottom tab bar (owner-made Kabso art,
// 2026-10-27, second package): Live · Moments · [ camera ] · Messages · Me.
// Every icon is drawn with a CustomPainter so each part can move:
//
// - Live: a house with a face — red sweeps in diagonally, the house rocks,
//   the "|" eye blinks, the play-triangle eye pops.
// - Moments: stacked cards (posts + reels) — the back card fans out, the
//   front card squashes and fills, the play pops, a star sparkles.
// - Messages: a round bubble fills and tilts, the dots bounce like typing;
//   the unread badge pops when its number changes.
// - Me: Kabi's head (no antennae) — asleep when idle ("z"), it wakes on
//   select: opens the play eye, hops and smiles.
// - Every tab: icon squash-and-bounce, a burst of sparks, the label lifts,
//   a soft rounded highlight behind the selected tab.
// - Centre: a red circle with a camera; static, only a light press
//   feedback.
//
// Colours come from the palette (light and dark); the reds are the brand
// reds. Reduced motion: the selection jumps to its end state (no sparks,
// no badge pop).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// What a [KTabBarItem] draws.
enum KTabKind { live, moments, create, messages, me }

/// One destination of the [KTabBar].
@immutable
class KTabBarItem {
  const new({
    required this.key,
    required this.kind,
    required this.label,
    this.badgeCount = 0,
    this.badgeLabel,
    this.dot = false,
    this.dotLabel,
  });

  /// Key of the item's semantics node (tests and the shell use it).
  final Key key;
  final KTabKind kind;

  /// Visible label; for [KTabKind.create] only the screen-reader name.
  final String label;

  /// A count badge (hidden at 0, "99+" above 99).
  final int badgeCount;

  /// What a screen reader says for the badge (e.g. "5 unread messages").
  final String? badgeLabel;

  /// A small dot (e.g. new stories); hidden while the item is selected.
  final bool dot;

  /// What a screen reader says for the dot.
  final String? dotLabel;
}

/// The app's bottom navigation (D130). Items are laid out in a [Row], so
/// the order follows the ambient [Directionality] (Arabic: the first item
/// at the right; English: at the left).
class KTabBar extends StatelessWidget {
  const new({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  final List<KTabBarItem> items;

  /// Index into [items] of the selected destination.
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// The bar's height above the bottom safe area.
  static const double height = 62;

  /// The centre (camera) button's diameter.
  static const double createSize = 52;

  /// The icons' box.
  static const double iconSize = 26;

  /// The labels scale at most this much (the bar has a fixed height).
  static const double maxTextScale = 1.15;

  @override
  Widget build(BuildContext context) {
    final c = _BarColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: c.dark ? Border(top: BorderSide(color: c.border)) : null,
        boxShadow: c.dark
            ? null
            : [
                BoxShadow(
                  color: c.shadow.withValues(alpha: .06),
                  offset: const Offset(0, -1),
                ),
                BoxShadow(
                  color: c.shadow.withValues(alpha: .05),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: KSpacing.xs),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: items[i].kind == KTabKind.create
                      ? _CreateButton(
                          item: items[i],
                          selected: i == currentIndex,
                          colors: c,
                          onTap: () => onSelect(i),
                        )
                      : _TabItem(
                          item: items[i],
                          selected: i == currentIndex,
                          colors: c,
                          onTap: () {
                            if (i != currentIndex) {
                              unawaited(HapticFeedback.selectionClick());
                            }
                            onSelect(i);
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar's colours from the palette: surfaces, greys, labels, the
/// highlight and the shadow follow light / dark; the reds are the brand
/// reds.
@immutable
class _BarColors {
  const new({
    required this.dark,
    required this.surface,
    required this.highlight,
    required this.border,
    required this.shadow,
    required this.idle,
    required this.label,
    required this.selectedLabel,
    required this.red,
    required this.redHi,
    required this.ink,
    required this.onRed,
  });

  factory of(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _BarColors(
      dark: dark,
      surface: p.surfaceRaised,
      highlight: dark ? p.surfaceOverlay : p.surface,
      border: p.border,
      shadow: p.scrim.withValues(alpha: 1),
      // Graphics ≥ 3:1 on the surface; labels ≥ 4.5:1.
      idle: p.borderStrong,
      label: p.textTertiary,
      selectedLabel: p.primaryText,
      red: p.primary,
      redHi: KBrandColors.red400,
      ink: p.textPrimary,
      onRed: p.onPrimary,
    );
  }

  final bool dark;

  /// The bar, and the inside of the icons' shapes.
  final Color surface;

  /// The soft rounded highlight behind the selected tab.
  final Color highlight;
  final Color border;
  final Color shadow;
  final Color idle;
  final Color label;
  final Color selectedLabel;
  final Color red;
  final Color redHi;

  /// Outlines of a selected icon.
  final Color ink;

  /// Glyphs on a red fill.
  final Color onRed;

  @override
  bool operator ==(Object other) =>
      other is _BarColors &&
      other.dark == dark &&
      other.surface == surface &&
      other.idle == idle &&
      other.red == red &&
      other.ink == ink;

  @override
  int get hashCode => Object.hash(dark, surface, idle, red, ink);
}

/// The owner's art accents: sparks, the star, Kabi's cheeks.
const List<Color> _sparkColours = [
  Color(0xFFFF2D3A),
  Color(0xFFFFB020),
  Color(0xFFFF6FA5),
];
const Color _star = Color(0xFFFFB020);
const Color _sparklePink = Color(0xFFFF6FA5);
const Color _cheek = Color(0x59FF5A6E);

double _c01(double v) => v.clamp(0.0, 1.0);
double _seg(double p, double a, double b) => _c01((p - a) / (b - a));
double _bump(double p, double a, double b) => math.sin(math.pi * _seg(p, a, b));

// ───────────────────────────── tab item ─────────────────────────────

class _TabItem extends StatefulWidget {
  const new({
    required this.item,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final KTabBarItem item;
  final bool selected;
  final _BarColors colors;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _TabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
    if (!widget.selected && oldWidget.selected) _c.value = 0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Squash → overshoot → settle.
  double _scale(double p) {
    if (!widget.selected) return 1;
    if (p < .16) return 1 - .2 * _seg(p, 0, .16);
    if (p < .5) return .8 + .34 * Curves.easeOut.transform(_seg(p, .16, .5));
    return 1.14 - .14 * Curves.easeInOut.transform(_seg(p, .5, 1));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = widget.colors;
    final on = widget.selected;
    final showDot = item.dot && !on;
    final showBadge = item.badgeCount > 0;
    final semanticsLabel = [
      item.label,
      if (showBadge && item.badgeLabel != null) item.badgeLabel!,
      if (showDot && item.dotLabel != null) item.dotLabel!,
    ].join(', ');
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KTabBar.maxTextScale);
    final labelStyle = context.textStyles.caption.copyWith(
      fontSize: 10.5,
      height: 1.2,
    );
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      key: item.key,
      button: true,
      selected: on,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final p = _c.value;
            final pill = on
                ? Curves.easeOutBack.transform(_seg(p, 0, .45))
                : 0.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                // A soft rounded highlight behind the selected tab.
                if (on)
                  Transform.scale(
                    scale: .6 + .4 * pill,
                    child: Opacity(
                      opacity: _c01(pill),
                      child: Container(
                        width: 64,
                        height: 52,
                        decoration: BoxDecoration(
                          color: c.highlight,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 28,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // A soft glow behind the icon.
                          if (on && p < 1)
                            OverflowBox(
                              maxWidth: 44,
                              maxHeight: 44,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      c.red.withValues(
                                        alpha: .16 * _bump(p, 0, 1),
                                      ),
                                      c.red.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Sparks.
                          if (on && p > .08 && p < .85)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _BurstPainter(_seg(p, .08, .85)),
                              ),
                            ),
                          Transform.scale(
                            scale: _scale(p),
                            child: SizedBox.square(
                              dimension: KTabBar.iconSize,
                              child: CustomPaint(
                                painter: _IconPainter(
                                  item.kind,
                                  on: on,
                                  p: p,
                                  c: c,
                                ),
                              ),
                            ),
                          ),
                          // The owner's art puts the badge and the dot at
                          // the icon's top right, in both directions.
                          if (item.kind == KTabKind.messages)
                            Positioned(
                              top: -6,
                              left: 16,
                              child: _CountBadge(
                                item.badgeCount,
                                c,
                                animate: !reduce,
                              ),
                            )
                          else if (showDot)
                            Positioned(top: -4, left: 19, child: _Dot(c)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Transform.translate(
                      offset: Offset(
                        0,
                        on
                            ? -1.5 * Curves.easeOut.transform(_seg(p, .1, .5))
                            : 0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KSpacing.xxs,
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: textScaler,
                          style: labelStyle.copyWith(
                            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                            color: on
                                ? Color.lerp(
                                    c.label,
                                    c.selectedLabel,
                                    _seg(p, 0, .3),
                                  )
                                : c.label,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────────── icons ─────────────────────────────

class _IconPainter extends CustomPainter {
  new(this.kind, {required this.on, required this.p, required this.c});

  final KTabKind kind;
  final bool on;
  final double p;
  final _BarColors c;

  // The red fill grows from the centre.
  double get _fill => on ? Curves.easeOut.transform(_seg(p, 0, .35)) : 0.0;

  Color get _inkC => on ? c.ink : c.idle;

  Paint _grad(Rect r) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c.redHi, c.red],
    ).createShader(r);

  Paint _stroke(Color colour, double w) => Paint()
    ..color = colour
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    switch (kind) {
      case KTabKind.live:
        _paintLive(canvas);
      case KTabKind.moments:
        _paintMoments(canvas);
      case KTabKind.messages:
        _paintMessages(canvas);
      case KTabKind.me:
        _paintMe(canvas);
      case KTabKind.create:
        // Drawn by _CreateButton.
        break;
    }
  }

  /// A house with a face: red sweeps in diagonally, the house rocks, the
  /// "|" eye blinks, the play-triangle eye pops.
  void _paintLive(Canvas canvas) {
    final f = on ? Curves.easeOut.transform(_seg(p, 0, .45)) : 0.0;
    final tilt = on ? math.sin(p * math.pi * 3) * (1 - p) * .12 : 0.0;
    canvas
      ..save()
      ..translate(12, 20)
      ..rotate(tilt)
      ..translate(-12, -20);
    final house = Path()
      ..moveTo(5, 17.4)
      ..lineTo(5, 11.3)
      ..quadraticBezierTo(5, 10.4, 5.7, 9.8)
      ..lineTo(10.7, 5.4)
      ..quadraticBezierTo(12, 4.3, 13.3, 5.4)
      ..lineTo(18.3, 9.8)
      ..quadraticBezierTo(19, 10.4, 19, 11.3)
      ..lineTo(19, 17.4)
      ..quadraticBezierTo(19, 20, 16.4, 20)
      ..lineTo(7.6, 20)
      ..quadraticBezierTo(5, 20, 5, 17.4)
      ..close();
    canvas.drawPath(house, Paint()..color = c.surface);
    if (f > 0) {
      final k = 44 - 20.5 * f;
      canvas
        ..save()
        ..clipPath(house)
        ..drawPath(
          Path()
            ..moveTo(k - 24, 24)
            ..lineTo(24, k - 24)
            ..lineTo(24, 24)
            ..close(),
          _grad(const Rect.fromLTRB(10, 10, 20, 20)),
        )
        ..restore();
    }
    final ink = _stroke(_inkC, 1.8);
    final bl = on ? 1 - .8 * _bump(p, .45, .6) : 1.0;
    final pop = on ? 1 + .45 * _bump(p, .25, .6) : 1.0;
    final eye = f > .9 ? c.onRed : _inkC;
    final tri = _tri(const Offset(14.2, 13.2), 1.75 * pop);
    canvas
      ..drawPath(house, ink)
      ..drawLine(
        Offset(9.6, 13.2 - 1.4 * bl),
        Offset(9.6, 13.2 + 1.4 * bl),
        ink,
      )
      ..drawPath(tri, Paint()..color = eye)
      ..drawPath(tri, _stroke(eye, .9)..strokeCap = StrokeCap.butt)
      ..restore();
  }

  /// Stacked cards: the back card fans out, the front card squashes, the
  /// play pops, a star sparkles.
  void _paintMoments(Canvas canvas) {
    final fill = _fill;
    final fan = (on ? 13 + 9 * _bump(p, .05, .6) : 13.0) * math.pi / 180;
    final back = RRect.fromRectAndRadius(
      const Rect.fromLTWH(7.4, 5.4, 10.6, 13.8),
      const Radius.circular(2.8),
    );
    final tint = Color.alphaBlend(c.red.withValues(alpha: .22), c.surface);
    canvas
      ..save()
      ..translate(12.6, 19.6)
      ..rotate(fan)
      ..translate(-12.6, -19.6)
      ..drawRRect(back, Paint()..color = Color.lerp(c.surface, tint, fill)!)
      ..drawRRect(back, _stroke(_inkC, 1.6))
      ..restore();
    final sq = on ? 1 - .1 * _bump(p, .05, .22) + .06 * _bump(p, .22, .5) : 1.0;
    final front = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.6, 6.6, 12.6, 14.4),
      const Radius.circular(3.2),
    );
    canvas
      ..save()
      ..translate(10, 20.4)
      ..scale(2 - sq, sq)
      ..translate(-10, -20.4)
      ..drawRRect(front, Paint()..color = c.surface);
    if (fill > 0) {
      canvas
        ..save()
        ..clipRRect(front)
        ..drawCircle(
          const Offset(9.9, 13.8),
          13 * fill,
          _grad(const Rect.fromLTWH(2, 2, 20, 20)),
        )
        ..restore();
    }
    canvas.drawRRect(front, _stroke(_inkC, 1.8));
    final pop = on ? 1 + .4 * _bump(p, .2, .55) : 1.0;
    canvas
      ..save()
      ..translate(9.9, 13.8)
      ..scale(pop);
    if (fill > .5) {
      canvas.drawCircle(
        Offset.zero,
        3.6,
        Paint()..color = c.onRed.withValues(alpha: .22),
      );
    }
    final triC = fill > .5 ? c.onRed : _inkC;
    final tri = _tri(const Offset(.45, 0), 2.3);
    canvas
      ..drawPath(tri, Paint()..color = triC)
      ..drawPath(tri, _stroke(triC, 1)..strokeCap = StrokeCap.butt)
      ..restore()
      ..restore();
    // The sparkle.
    final tw = on ? _bump(p, .3, .8) : 0.0;
    final star = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final r = i.isOdd ? .6 : 2.3;
      final pt = Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    canvas
      ..save()
      ..translate(19.6, 5.2)
      ..rotate(tw * math.pi / 2)
      ..scale(1 + .6 * tw)
      ..drawPath(star..close(), Paint()..color = on ? _star : c.idle)
      ..restore();
    if (on && tw > 0) {
      canvas
        ..drawCircle(
          const Offset(21.6, 9),
          .7,
          Paint()..color = _sparklePink.withValues(alpha: tw),
        )
        ..drawCircle(
          const Offset(17, 2.4),
          .55,
          Paint()..color = _star.withValues(alpha: tw),
        );
    }
  }

  /// A round bubble with its tail at the bottom right; the dots bounce
  /// like typing.
  void _paintMessages(Canvas canvas) {
    final fill = _fill;
    final tilt = on ? math.sin(p * math.pi * 3) * (1 - p) * .16 : 0.0;
    final bubble = Path()
      ..arcTo(
        Rect.fromCircle(center: const Offset(11.4, 11.4), radius: 8.2),
        1,
        .36 + 2 * math.pi - 1.0,
        true,
      )
      ..quadraticBezierTo(19.6, 17.4, 20.6, 20.2)
      ..quadraticBezierTo(17.6, 19.8, 15.8, 18.3)
      ..close();
    canvas
      ..save()
      ..translate(18, 19)
      ..rotate(tilt)
      ..translate(-18, -19)
      ..drawPath(bubble, Paint()..color = c.surface);
    if (fill > 0) {
      canvas
        ..save()
        ..clipPath(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(12, 12), radius: 17 * fill),
          ),
        )
        ..drawPath(bubble, _grad(const Rect.fromLTWH(2, 2, 20, 20)))
        ..restore();
    }
    canvas.drawPath(bubble, _stroke(_inkC, 1.8)..strokeCap = StrokeCap.butt);
    final dot = Paint()..color = fill > .5 ? c.onRed : _inkC;
    for (var i = 0; i < 3; i++) {
      final hop = on ? 2.2 * _bump(p, .22 + i * .1, .5 + i * .1) : 0.0;
      canvas.drawCircle(Offset(7.8 + 3.6 * i, 11.4 - hop), 1.3, dot);
    }
    canvas.restore();
  }

  /// Kabi's head (no antennae): asleep when idle, it wakes on select —
  /// opens the play eye, hops and smiles.
  void _paintMe(Canvas canvas) {
    final fill = _fill;
    final hop = on ? 2 * _bump(p, .1, .42) - .6 * _bump(p, .42, .6) : 0.0;
    final sq = on ? 1 - .12 * _bump(p, .42, .55) : 1.0;
    final body = Path()
      ..addOval(
        Rect.fromCenter(
          center: const Offset(12, 13.3),
          width: 16.8,
          height: 14,
        ),
      );
    // The head only, enlarged to fill the icon box.
    canvas
      ..save()
      ..translate(12, 12.4)
      ..scale(1.24)
      ..translate(-12, -13.3)
      ..save()
      ..translate(12, 20)
      ..scale(2 - sq, sq)
      ..translate(-12, -20 - hop)
      ..drawPath(body, Paint()..color = c.surface)
      ..save()
      ..clipPath(body);
    if (fill > 0) {
      canvas
        ..clipPath(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(12, 13), radius: 17 * fill),
          ),
        )
        ..drawRect(
          const Rect.fromLTRB(0, 0, 24, 10.2),
          _grad(const Rect.fromLTWH(2, 2, 20, 20)),
        );
    } else {
      canvas.drawLine(
        const Offset(2, 10.2),
        const Offset(22, 10.2),
        _stroke(_inkC, 1.4),
      );
    }
    canvas
      ..restore()
      ..drawPath(body, _stroke(_inkC, 1.6));
    // The eye: closed while asleep, the play eye once awake.
    final openE = on ? _seg(p, .3, .5) : 0.0;
    if (openE < .5) {
      canvas.drawPath(
        Path()
          ..moveTo(9.6, 13)
          ..quadraticBezierTo(12, 14.8, 14.4, 13),
        _stroke(_inkC, 1.6),
      );
    } else {
      canvas
        ..save()
        ..translate(12, 12.9)
        ..scale(1, (openE - .5) * 2)
        ..drawCircle(Offset.zero, 3.3, Paint()..color = c.ink)
        ..drawPath(_tri(const Offset(.3, 0), 1.55), Paint()..color = c.red)
        ..drawCircle(const Offset(-1.9, -1.8), .55, Paint()..color = c.surface)
        ..restore();
    }
    // The smile and the cheeks.
    canvas.drawPath(
      Path()
        ..moveTo(10.6, 17.1)
        ..quadraticBezierTo(
          12,
          18.1 + (on ? .5 * _bump(p, .4, .8) : 0),
          13.4,
          17.1,
        ),
      _stroke(_inkC, 1.3),
    );
    if (fill > 0) {
      final cheek = Paint()..color = _cheek;
      canvas
        ..drawOval(
          Rect.fromCenter(
            center: const Offset(7.3, 15.6),
            width: 2.4,
            height: 1.4,
          ),
          cheek,
        )
        ..drawOval(
          Rect.fromCenter(
            center: const Offset(16.7, 15.6),
            width: 2.4,
            height: 1.4,
          ),
          cheek,
        );
    }
    canvas
      ..restore()
      ..restore();
    // A little "z" while asleep.
    if (!on) {
      canvas.drawPath(
        Path()
          ..moveTo(19.3, 4.6)
          ..lineTo(21.3, 4.6)
          ..lineTo(19.3, 7)
          ..lineTo(21.3, 7),
        _stroke(c.idle, .9),
      );
    }
  }

  Path _tri(Offset o, double r) => Path()
    ..moveTo(o.dx + r * 1.05, o.dy)
    ..lineTo(o.dx - r * .55, o.dy - r * .95)
    ..lineTo(o.dx - r * .55, o.dy + r * .95)
    ..close();

  @override
  bool shouldRepaint(covariant _IconPainter o) =>
      o.p != p || o.on != on || o.kind != kind || o.c != c;
}

class _BurstPainter extends CustomPainter {
  new(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final e = Curves.easeOut.transform(t);
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4 + .2;
      final r = 11 + 12 * e;
      final s = (i.isEven ? 2.2 : 1.6) * (1 - t);
      canvas.drawCircle(
        centre + Offset(math.cos(a) * r, math.sin(a) * r),
        s,
        Paint()..color = _sparkColours[i % 3].withValues(alpha: 1 - t * .6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter o) => o.t != t;
}

// ───────────────────────────── centre button ─────────────────────────────

/// The red circle with a camera: static, only a light press feedback. The
/// whole cell is the touch target.
class _CreateButton extends StatefulWidget {
  const new({
    required this.item,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final KTabBarItem item;
  final bool selected;
  final _BarColors colors;
  final VoidCallback onTap;

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton> {
  bool _down = false;

  void _pressDown() {
    if (!_down) setState(() => _down = true);
  }

  void _release() {
    if (_down) setState(() => _down = false);
  }

  void _fire() {
    unawaited(HapticFeedback.lightImpact());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: widget.item.key,
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      excludeSemantics: true,
      onTap: _fire,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _pressDown(),
        onTapCancel: _release,
        onTapUp: (_) => _release(),
        onTap: _fire,
        child: Center(
          child: AnimatedScale(
            scale: _down ? .93 : 1,
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 100),
            child: Container(
              width: KTabBar.createSize,
              height: KTabBar.createSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.redHi, c.red],
                ),
              ),
              child: CustomPaint(
                size: const Size.square(32),
                painter: _CameraPainter(body: c.onRed, play: c.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A video camera: rounded body with a red play triangle, a soft lens on
/// the side.
class _CameraPainter extends CustomPainter {
  const new({required this.body, required this.play});

  final Color body;
  final Color play;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final lens = Path()
      ..moveTo(17.6, 10.2)
      ..lineTo(20.4, 8.3)
      ..quadraticBezierTo(21.6, 7.6, 21.6, 9)
      ..lineTo(21.6, 15)
      ..quadraticBezierTo(21.6, 16.4, 20.4, 15.7)
      ..lineTo(17.6, 13.8)
      ..close();
    final tri = Path()
      ..moveTo(12.4, 12)
      ..lineTo(7.8, 9.2)
      ..lineTo(7.8, 14.8)
      ..close();
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2.4, 5.6, 14, 12.8),
          const Radius.circular(3.8),
        ),
        Paint()..color = body,
      )
      ..drawPath(lens, Paint()..color = body.withValues(alpha: .72))
      ..drawPath(tri, Paint()..color = play)
      ..drawPath(
        tri,
        Paint()
          ..color = play
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(covariant _CameraPainter oldDelegate) =>
      oldDelegate.body != body || oldDelegate.play != play;
}

// ───────────────────────────── badges ─────────────────────────────

/// The unread counter: hidden at 0, pops whenever the number changes,
/// "99+" above 99.
class _CountBadge extends StatelessWidget {
  const new(this.count, this.colors, {required this.animate});

  final int count;
  final _BarColors colors;
  final bool animate;

  static const Key badgeKey = Key('nav.badge');

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return AnimatedSwitcher(
      duration: animate ? const Duration(milliseconds: 380) : Duration.zero,
      switchInCurve: Curves.elasticOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: count <= 0
          ? const SizedBox.shrink(key: ValueKey('nav.badge.none'))
          : Container(
              // A new number is a new child: it pops in.
              key: ValueKey('nav.badge.$text'),
              constraints: const BoxConstraints(minWidth: 17),
              padding: const EdgeInsets.symmetric(
                horizontal: 4.5,
                vertical: 2.5,
              ),
              decoration: BoxDecoration(
                color: colors.red,
                borderRadius: BorderRadius.circular(KRadius.pill),
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              child: Text(
                text,
                key: badgeKey,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
                style: context.textStyles.caption.copyWith(
                  color: colors.onRed,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
    );
  }
}

class _Dot extends StatelessWidget {
  const new(this.colors);

  final _BarColors colors;

  static const Key dotKey = Key('nav.dot');

  @override
  Widget build(BuildContext context) => Container(
    key: dotKey,
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: colors.red,
      shape: BoxShape.circle,
      border: Border.all(color: colors.surface, width: 1.5),
    ),
  );
}

/// Keys of the bar's badge text and dot (tests).
abstract final class KTabBarKeys {
  static const Key badge = _CountBadge.badgeKey;
  static const Key dot = _Dot.dotKey;
}
