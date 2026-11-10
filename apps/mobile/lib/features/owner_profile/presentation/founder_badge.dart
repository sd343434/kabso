// D357 (owner, 2026-11-10: «الشارة مثلما كانت لكن بدل ما بداخلها صح يصبح
// مثلث»): the founder's badge on his page — the D293 verification seal
// «شارة التوثيق» itself (the 8-lobe rosette of [VerificationSealPainter],
// not a copy of its maths) in Kabso red ([FounderBadge.fill]), holding a
// solid white play triangle with rounded corners ([FounderPlayPainter])
// where the other seals hold their check mark. Replaces the seal on the
// founder's page only.

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The founder's red seal, read as «مؤسس Kabso Live» / "Kabso Live
/// founder" (one label; a tooltip on long press).
class FounderBadge extends StatelessWidget {
  const new({super.key, this.size = 23});

  /// The seal's width and height. On his page: the D293 seal's size beside
  /// a name of the same font ([ProfileVerificationBadge.sizeForFont]).
  final double size;

  /// The seal: the brand red (white on it 4.8 : 1, over the 3 : 1 needed
  /// for a graphic); the same on light and dark pages, like the D293 seals.
  static const Color fill = KBrandColors.red500;

  /// The triangle.
  static const Color ink = Color(0xFFFFFFFF);

  static const badgeKey = Key('founder.badge');

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.founderBadgeLabel;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        key: badgeKey,
        label: label,
        image: true,
        container: true,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: const CustomPaint(
            painter: VerificationSealPainter(fill: fill),
            foregroundPainter: FounderPlayPainter(color: ink),
          ),
        ),
      ),
    );
  }
}

/// D357: the founder seal's play triangle — solid, pointing right in both
/// reading directions (a media "play", never mirrored), its corners rounded
/// by a round-joined stroke of the same colour. Its corners span [width] ×
/// [height] of the box (the rounding adds [round] around them: about 0.35 ×
/// 0.39 drawn, as in the owner-approved preview), and its box is moved
/// [nudge] toward the point so the triangle's weight (its flat side) does not
/// pull it off the seal's centre.
class FounderPlayPainter extends CustomPainter {
  const new({required this.color});

  final Color color;

  /// The triangle's corners, as shares of the seal (owner-approved preview).
  static const double width = 0.30;
  static const double height = 0.34;

  /// The rounding: the stroke's width as a share of the seal.
  static const double round = 0.045;

  /// The shift of its box toward the point, as a share of the seal.
  static const double nudge = 0.035;

  /// The triangle's corners (before the rounding) in a box of [size]:
  /// top-left, the point (centre-right), bottom-left.
  static List<Offset> corners(Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero) + Offset(s * nudge, 0);
    final halfW = s * width / 2;
    final halfH = s * height / 2;
    return [
      c + Offset(-halfW, -halfH),
      c + Offset(halfW, 0),
      c + Offset(-halfW, halfH),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = corners(size);
    final path = Path()
      ..moveTo(p[0].dx, p[0].dy)
      ..lineTo(p[1].dx, p[1].dy)
      ..lineTo(p[2].dx, p[2].dy)
      ..close();
    final paint = Paint()
      ..isAntiAlias = true
      ..color = color
      ..style = PaintingStyle.fill;
    canvas
      ..drawPath(path, paint)
      ..drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(FounderPlayPainter old) => old.color != color;
}
