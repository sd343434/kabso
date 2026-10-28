import 'package:kabso_live/features/live/presentation/go_live/live_room_style.dart';
import 'package:material_ui/material_ui.dart';

/// D143 fill light with the front camera: the screen itself lights the
/// face — a warm white frame that glows inwards around the camera picture
/// (on the host's screen only; the published picture is the camera's).
///
/// It fades in, or appears at once when the system asks for less motion.
/// It never takes a touch.
class LiveFillLightFrame extends StatelessWidget {
  const new({required this.on, super.key});

  final bool on;

  static const frameKey = Key('fillLight.frame');

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: on
            ? const CustomPaint(
                key: frameKey,
                painter: _FillLightPainter(),
                child: SizedBox.expand(),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _FillLightPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final band = (shortest * KLiveStyle.fillLightBand).clamp(18.0, 44.0);
    final rect = Offset.zero & size;
    // The solid light band along every edge…
    final inner = RRect.fromRectAndRadius(
      rect.deflate(band),
      Radius.circular(band),
    );
    canvas
      ..drawDRRect(
        RRect.fromRectAndRadius(rect, Radius.zero),
        inner,
        Paint()..color = KLiveStyle.fillLight,
      )
      // …and its glow spilling inwards.
      ..save()
      ..clipRRect(inner)
      ..drawRRect(
        inner,
        Paint()
          ..color = KLiveStyle.fillLightGlow
          ..style = PaintingStyle.stroke
          ..strokeWidth = band
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, band * 0.6),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_FillLightPainter oldDelegate) => false;
}
