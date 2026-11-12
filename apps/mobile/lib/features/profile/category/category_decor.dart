import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/category/category_style.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D386 (CONVENTIONS §10.175.2): the decoration of a verified category's
/// page — the cover's accent tint with the category's pattern, and the
/// category badge beside the name (the category's icon with a small check).

/// A low-opacity motif drawn in code (no third-party art), tiled over the
/// area: music notes, calligraphic flourishes, newspaper columns, picture
/// frames, spotlights, chevrons or waves.
class CategoryPatternPainter extends CustomPainter {
  const new({required this.pattern, required this.color});

  final CategoryPattern pattern;
  final Color color;

  /// The tile (dp): one motif per cell, every other row shifted.
  static const double cell = 46;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == CategoryPattern.none) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    if (pattern == CategoryPattern.lines) {
      _columns(canvas, size, stroke);
      return;
    }
    var row = 0;
    for (var y = cell / 2; y < size.height + cell; y += cell, row++) {
      final shift = row.isOdd ? cell / 2 : 0.0;
      var col = 0;
      for (var x = cell / 2 + shift; x < size.width + cell; x += cell, col++) {
        // A fixed variation per cell (rotation and size), the same on
        // every frame and in every golden.
        final seed = (row * 7 + col * 13) % 5;
        canvas
          ..save()
          ..translate(x, y)
          ..rotate((seed - 2) * 0.16);
        final s = 0.85 + seed * 0.06;
        canvas.scale(s);
        switch (pattern) {
          case CategoryPattern.notes:
            _note(canvas, stroke, fill, beamed: seed.isEven);
          case CategoryPattern.flourish:
            _flourish(canvas, stroke, fill);
          case CategoryPattern.frames:
            _frame(canvas, stroke, fill);
          case CategoryPattern.sparkles:
            _sparkle(canvas, fill, big: seed.isOdd);
          case CategoryPattern.chevrons:
            _chevron(canvas, stroke);
          case CategoryPattern.waves:
            _wave(canvas, stroke);
          case CategoryPattern.lines || CategoryPattern.none:
            break;
        }
        canvas.restore();
      }
    }
  }

  void _note(Canvas c, Paint stroke, Paint fill, {required bool beamed}) {
    c
      ..drawOval(
        Rect.fromCenter(center: const Offset(-5, 7), width: 8, height: 6),
        fill,
      )
      ..drawLine(const Offset(-1.2, 6.5), const Offset(-1.2, -9), stroke);
    if (beamed) {
      c
        ..drawOval(
          Rect.fromCenter(center: const Offset(8, 5), width: 8, height: 6),
          fill,
        )
        ..drawLine(const Offset(11.8, 4.5), const Offset(11.8, -11), stroke)
        ..drawLine(const Offset(-1.2, -9), const Offset(11.8, -11), stroke);
    } else {
      final flag = Path()
        ..moveTo(-1.2, -9)
        ..quadraticBezierTo(6, -6, 4, 0);
      c.drawPath(flag, stroke);
    }
  }

  void _flourish(Canvas c, Paint stroke, Paint fill) {
    // A calligraphic swash: an S-curve with a curl and a diacritic dot.
    final p = Path()
      ..moveTo(-14, 4)
      ..cubicTo(-8, -10, 0, 10, 6, -2)
      ..cubicTo(9, -8, 15, -6, 13, 0)
      ..cubicTo(11, 5, 5, 3, 7, -1);
    c
      ..drawPath(p, stroke)
      ..drawCircle(const Offset(-4, -8), 1.6, fill)
      ..drawCircle(const Offset(1, 10), 1.2, fill);
  }

  void _frame(Canvas c, Paint stroke, Paint fill) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 20, height: 16),
      const Radius.circular(2.5),
    );
    c.drawRRect(r, stroke);
    final hill = Path()
      ..moveTo(-8, 6)
      ..lineTo(-2, -1)
      ..lineTo(2, 3)
      ..lineTo(5, 0)
      ..lineTo(8, 6);
    c
      ..drawPath(hill, stroke)
      ..drawCircle(const Offset(4.5, -3.5), 1.6, fill);
  }

  void _sparkle(Canvas c, Paint fill, {required bool big}) {
    final r = big ? 8.0 : 5.0;
    final p = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..quadraticBezierTo(0, 0, 0, r)
      ..quadraticBezierTo(0, 0, -r, 0)
      ..quadraticBezierTo(0, 0, 0, -r)
      ..close();
    c.drawPath(p, fill);
  }

  void _chevron(Canvas c, Paint stroke) {
    for (final dy in const [-4.0, 4.0]) {
      final p = Path()
        ..moveTo(-9, dy + 4)
        ..lineTo(0, dy - 4)
        ..lineTo(9, dy + 4);
      c.drawPath(p, stroke);
    }
  }

  void _wave(Canvas c, Paint stroke) {
    final p = Path()..moveTo(-15, 0);
    for (var i = 0; i < 3; i++) {
      final x = -15.0 + i * 10;
      p
        ..quadraticBezierTo(x + 2.5, i.isEven ? -6 : 6, x + 5, 0)
        ..quadraticBezierTo(x + 7.5, i.isEven ? 6 : -6, x + 10, 0);
    }
    c.drawPath(p, stroke);
  }

  /// Newspaper columns: three columns of lines with a heading bar.
  void _columns(Canvas c, Size size, Paint stroke) {
    const gap = 14.0;
    final column = (size.width - gap * 4) / 3;
    for (var i = 0; i < 3; i++) {
      final x0 = gap + i * (column + gap);
      var y = gap;
      var line = 0;
      while (y < size.height) {
        final heading = line % 9 == 0;
        final shortLine = line % 9 == 8;
        final w = heading
            ? column * 0.7
            : shortLine
            ? column * 0.45
            : column;
        c.drawLine(
          Offset(x0, y),
          Offset(x0 + w, y),
          heading ? (Paint.from(stroke)..strokeWidth = 3.2) : stroke,
        );
        y += heading ? 11 : 7;
        line++;
      }
    }
  }

  @override
  bool shouldRepaint(CategoryPatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern || oldDelegate.color != color;
}

/// The cover layer of a verified category: the accent tint (stronger at the
/// bottom, where the photo sits) and the pattern at low opacity. It never
/// takes a tap.
class CategoryCoverOverlay extends StatelessWidget {
  const new({required this.look, super.key});

  final CategoryLook look;

  static const overlayKey = Key('profile.category.cover');

  /// The tint's opacity at the bottom and at the top of the cover.
  static const double tintBottom = 0.55;
  static const double tintTop = 0.12;

  /// The pattern's opacity.
  static const double patternOpacity = 0.22;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    key: overlayKey,
    child: Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                look.accent.withValues(alpha: tintBottom),
                look.accent.withValues(alpha: tintTop),
              ],
            ),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: CategoryPatternPainter(
              pattern: look.pattern,
              color: const Color(0xFFFFFFFF).withValues(alpha: patternOpacity),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The category badge beside the name: a round accent disc with the
/// category's icon and a small check on its corner (the team verified it).
/// Read aloud «فئة موثّقة: شاعر».
class CategoryBadge extends StatelessWidget {
  const new({required this.look, this.size = 23, super.key});

  final CategoryLook look;

  /// The disc's diameter (≈ the name's line height, like the D293 seal).
  final double size;

  static const badgeKey = Key('profile.category.badge');
  static const checkKey = Key('profile.category.badge.check');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = context.palette.background;
    final check = size * 0.48;
    return Semantics(
      label: l10n.categoryBadgeVerified(categoryLabel(l10n, look.category)),
      excludeSemantics: true,
      child: SizedBox.square(
        key: badgeKey,
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: look.accent,
              ),
              child: Center(
                child: AppIcon(
                  look.icon,
                  size: size * 0.62,
                  color: look.onAccent,
                ),
              ),
            ),
            PositionedDirectional(
              end: -check * 0.25,
              bottom: -check * 0.2,
              child: Container(
                key: checkKey,
                width: check,
                height: check,
                decoration: BoxDecoration(shape: BoxShape.circle, color: page),
                padding: EdgeInsets.all(check * 0.12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: look.accent,
                  ),
                  child: CustomPaint(painter: _CheckPainter(look.onAccent)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.16)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.68)
      ..lineTo(s * 0.74, s * 0.36);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => oldDelegate.color != color;
}
