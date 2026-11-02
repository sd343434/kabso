import 'dart:math' as math;

import 'package:kabso_live/features/live/games/ludo/domain/ludo_board.dart';
import 'package:material_ui/material_ui.dart';

/// D168: the Ludo art of the owner-approved prototype, drawn in code (no
/// third-party art): the board, the airplane, the stars, the arrows and
/// the treasure chest of the rank pill.
abstract final class LudoArt {
  static const panelTop = Color(0xFF8FD0FF);
  static const panelMiddle = Color(0xFF5AAEF6);
  static const panelEdge = Color(0xFF3E8EE6);
  static const boardTop = Color(0xFFB9A6FF);
  static const boardBottom = Color(0xFF7E63E6);
  static const boardRing = Color(0xFFA68FFF);
  static const boardShadow = Color(0xFF5B3FC9);
  static const cell = Color(0xFFFFFFFF);
  static const cellEdge = Color(0xFFC9DDF2);
  static const starCell = Color(0xFFD7ECFF);
  static const starCellEdge = Color(0xFFA9CCEE);
  static const star = Color(0xFF8CC3F2);
  static const centre = Color(0xFF6E55D6);
  static const ink = Color(0xFF1A1440);
  static const status = Color(0xFF0E3A73);
  static const gold = Color(0xFFFFD34D);
  static const rankTop = Color(0xFF2E86DA);
  static const rankBottom = Color(0xFF1E6CC0);

  /// [c] mixed with white ([t] of white) or black (negative [t]).
  static Color mix(Color c, double t) =>
      Color.lerp(c, t >= 0 ? Colors.white : Colors.black, t.abs())!;

  /// A five-point star filling [rect] (the prototype's star).
  static Path star5(Rect rect) {
    final path = Path();
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final outer = rect.shortestSide / 2;
    final inner = outer * 0.45;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  /// The airplane of a piece (24 × 24 units), pointing to the reading
  /// end of the board like the prototype's, scaled into [rect].
  static Path plane(Rect rect) {
    final k = rect.width / 24;
    // The prototype's plane, turned a quarter anticlockwise round (12, 12).
    Offset p(double x, double y) =>
        Offset(rect.left + y * k, rect.top + (24 - x) * k);
    final points = [
      p(21, 15.5),
      p(21, 13.5),
      p(13, 8.5),
      p(13, 3.5),
    ];
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (final q in points.skip(1)) {
      path.lineTo(q.dx, q.dy);
    }
    final nose = p(10, 3.5);
    path.arcToPoint(
      nose,
      radius: Radius.circular(1.5 * k),
      clockwise: false,
    );
    for (final (x, y) in const <(double, double)>[
      (10, 8.5),
      (2, 13.5),
      (2, 15.5),
      (10, 13),
      (10, 18),
      (8, 19.5),
      (8, 21),
      (11.5, 20),
      (15, 21),
      (15, 19.5),
      (13, 18),
      (13, 13),
    ]) {
      final q = p(x, y);
      path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }
}

/// The board: bases, track, home columns and the four-colour centre
/// (15 × 15 cells, the prototype's layout and colours).
class LudoBoardPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final u = s / LudoBoard.cells;
    final outer = RRect.fromRectAndRadius(
      Offset.zero & Size.square(s),
      Radius.circular(s * 0.055),
    );
    // The 3D slab: a soft shadow, the dark lip, the light ring.
    canvas
      ..drawRRect(
        outer.shift(const Offset(0, 14)).inflate(2),
        Paint()
          ..color = const Color(0x59000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      )
      ..drawRRect(
        outer.shift(const Offset(0, 8)).inflate(4),
        Paint()..color = LudoArt.boardShadow,
      )
      ..drawRRect(outer.inflate(4), Paint()..color = LudoArt.boardRing)
      ..drawRRect(
        outer,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LudoArt.boardTop, LudoArt.boardBottom],
          ).createShader(outer.outerRect),
      );
    for (var seat = 0; seat < 4; seat++) {
      _base(canvas, seat, u);
    }
    for (var i = 0; i < LudoBoard.track.length; i++) {
      final (r, c) = LudoBoard.track[i];
      final own = LudoBoard.start.indexOf(i);
      final entry = LudoBoard.start.indexWhere(
        (st) => (st + LudoBoard.track.length - 1) % LudoBoard.track.length == i,
      );
      if (own >= 0) {
        _cell(canvas, r, c, u, fill: LudoBoard.colors[own]);
        _arrow(canvas, r, c, u, LudoBoard.arrowTurns[own], Colors.white);
      } else if (entry >= 0) {
        _cell(canvas, r, c, u);
        _arrow(
          canvas,
          r,
          c,
          u,
          LudoBoard.arrowTurns[entry],
          LudoBoard.colors[entry],
        );
      } else {
        _cell(canvas, r, c, u, star: LudoBoard.safe.contains(i));
      }
    }
    for (var seat = 0; seat < 4; seat++) {
      for (final (r, c) in LudoBoard.home[seat]) {
        _cell(canvas, r, c, u, fill: LudoBoard.colors[seat]);
      }
    }
    _centre(canvas, u);
  }

  void _cell(
    Canvas canvas,
    int r,
    int c,
    double u, {
    Color? fill,
    bool star = false,
  }) {
    final pad = u * 0.06;
    final rect = Rect.fromLTWH(c * u + pad, r * u + pad, u - 2 * pad, u - 2 * pad);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(u * 0.12));
    final face = fill ?? (star ? LudoArt.starCell : LudoArt.cell);
    final edge = fill != null
        ? LudoArt.mix(fill, -0.3)
        : (star ? LudoArt.starCellEdge : LudoArt.cellEdge);
    canvas
      ..drawRRect(rr, Paint()..color = edge)
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - u * 0.08),
          topLeft: rr.tlRadius,
          topRight: rr.trRadius,
          bottomLeft: rr.blRadius,
          bottomRight: rr.brRadius,
        ),
        Paint()..color = face,
      );
    if (star) {
      canvas.drawPath(
        LudoArt.star5(rect.deflate(rect.width * 0.24)),
        Paint()..color = LudoArt.star,
      );
    }
  }

  /// An arrow (the prototype's: a shaft and a head) turned [turns]
  /// quarter-turns clockwise from pointing right.
  void _arrow(Canvas canvas, int r, int c, double u, int turns, Color color) {
    final centre = Offset(c * u + u / 2, r * u + u / 2);
    final k = u * 0.52 / 24;
    final path = Path()
      ..moveTo(-8 * k, 0)
      ..lineTo(4 * k, 0)
      ..moveTo(0, -6 * k)
      ..lineTo(6 * k, 0)
      ..lineTo(0, 6 * k);
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(turns * math.pi / 2)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * k
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  void _base(Canvas canvas, int seat, double u) {
    final (r, c) = LudoBoard.base[seat];
    final color = LudoBoard.colors[seat];
    final rect = Rect.fromLTWH(c * u, r * u, 6 * u, 6 * u).deflate(u * 0.18);
    final outer = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.width * 0.18),
    );
    canvas
      ..drawRRect(
        outer.shift(Offset(0, u * 0.12)),
        Paint()..color = LudoArt.mix(color, -0.4),
      )
      ..drawRRect(
        outer,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LudoArt.mix(color, 0.3),
              color,
              LudoArt.mix(color, -0.2),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(rect),
      )
      ..drawRRect(
        outer.deflate(u * 0.05),
        Paint()
          ..color = const Color(0x73FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.06,
      );
    final innerRect = Rect.fromCenter(
      center: rect.center,
      width: rect.width * 0.78,
      height: rect.height * 0.78,
    );
    final inner = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(innerRect.width * 0.16),
    );
    canvas
      ..drawRRect(inner, Paint()..color = LudoArt.mix(color, 0.25))
      ..drawRRect(
        inner,
        Paint()
          ..color = const Color(0x26000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.08,
      );
    for (final (x, y) in const [
      (0.27, 0.27),
      (0.73, 0.27),
      (0.27, 0.73),
      (0.73, 0.73),
    ]) {
      final centre = Offset(
        innerRect.left + innerRect.width * x,
        innerRect.top + innerRect.height * y,
      );
      final radius = innerRect.width * 0.15;
      canvas
        ..drawCircle(centre, radius, Paint()..color = LudoArt.mix(color, 0.45))
        ..drawCircle(
          centre,
          radius,
          Paint()
            ..color = const Color(0x2E000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * 0.06,
        );
    }
  }

  void _centre(Canvas canvas, double u) {
    final rect = Rect.fromLTWH(6 * u, 6 * u, 3 * u, 3 * u);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(u * 0.25));
    canvas
      ..save()
      ..clipRRect(rr)
      ..drawRect(rect, Paint()..color = LudoArt.centre);
    final m = rect.center;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    // Red left, green top, yellow right, blue bottom.
    final petals = [
      (corners[0], corners[3], 0, Offset(rect.left + rect.width * 0.21, m.dy)),
      (corners[0], corners[1], 1, Offset(m.dx, rect.top + rect.height * 0.21)),
      (
        corners[1],
        corners[2],
        2,
        Offset(rect.right - rect.width * 0.21, m.dy),
      ),
      (
        corners[3],
        corners[2],
        3,
        Offset(m.dx, rect.bottom - rect.height * 0.21),
      ),
    ];
    final starPaint = Paint()..color = const Color(0xE6FFFFFF);
    for (final (a, b, seat, at) in petals) {
      canvas
        ..drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(m.dx, m.dy)
            ..lineTo(b.dx, b.dy)
            ..close(),
          Paint()..color = LudoBoard.colors[seat],
        )
        ..drawPath(
          LudoArt.star5(Rect.fromCenter(center: at, width: u * 0.9, height: u * 0.9)),
          starPaint,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LudoBoardPainter oldDelegate) => false;
}

/// The airplane on a piece's disc.
class LudoPlanePainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      LudoArt.plane(Offset.zero & size),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(LudoPlanePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The treasure chest of the rank pill (our own drawing of the
/// prototype's vector chest, 44 × 40 units).
class LudoChestPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 44;
    canvas
      ..save()
      ..scale(k, k)
      ..drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTRB(4, 18, 40, 39),
          bottomLeft: const Radius.circular(3),
          bottomRight: const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFA85A1E),
      )
      ..drawPath(
        Path()
          ..moveTo(4, 18)
          ..cubicTo(4, 9, 12, 4, 22, 4)
          ..cubicTo(32, 4, 40, 9, 40, 18)
          ..close(),
        Paint()..color = const Color(0xFFC8742A),
      )
      ..drawRect(
        const Rect.fromLTRB(4, 18, 40, 22),
        Paint()..color = const Color(0xFFF2B233),
      )
      ..drawRect(
        const Rect.fromLTRB(19, 17, 25, 26),
        Paint()..color = LudoArt.gold,
      )
      ..drawCircle(
        const Offset(22, 21.5),
        1.6,
        Paint()..color = const Color(0xFF7A3F10),
      )
      ..drawCircle(const Offset(14, 9), 3, Paint()..color = LudoArt.gold)
      ..drawCircle(
        const Offset(29, 8),
        2.5,
        Paint()..color = const Color(0xFFFFE27A),
      )
      ..drawCircle(const Offset(22, 6), 2.5, Paint()..color = LudoArt.gold)
      ..restore();
  }

  @override
  bool shouldRepaint(LudoChestPainter oldDelegate) => false;
}

/// The turn timer around the active player's chip: what is left of the
/// turn, in the seat's colour.
class LudoRingPainter extends CustomPainter {
  const new({required this.left, required this.color});

  /// 1 at the start of the turn, 0 when it is up.
  final double left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (left <= 0) return;
    final stroke = size.width * 0.09;
    canvas.drawArc(
      (Offset.zero & size).deflate(stroke / 2),
      -math.pi / 2,
      2 * math.pi * left.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(LudoRingPainter oldDelegate) =>
      oldDelegate.left != left || oldDelegate.color != color;
}
