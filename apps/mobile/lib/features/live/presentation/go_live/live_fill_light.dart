import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_style.dart';
import 'package:material_ui/material_ui.dart';

/// D157 fill light's fallback with the front camera, where the device has
/// no camera pipeline to lift the picture itself (D143's colour stage): a
/// thin warm glow at the very edges of the camera picture — at most 3.5 % of
/// the width, low opacity, fading inwards — on the host's screen only.
/// Where the pipeline exists the light is on the published picture instead
/// and this is not drawn (see `LiveBeauty.light`).
///
/// It fades in, or appears at once when the system asks for less motion.
/// It never takes a touch, and it sits under every control.
class LiveFillLightFrame extends StatelessWidget {
  const new({required this.on, this.level = LiveFillLight.medium, super.key});

  final bool on;
  final LiveFillLight level;

  static const frameKey = Key('fillLight.frame');

  /// The glow's opacity at the very edge for [level].
  static double edgeOpacity(LiveFillLight level) => switch (level) {
    LiveFillLight.off => 0,
    LiveFillLight.low => 0.22,
    LiveFillLight.medium => 0.32,
    LiveFillLight.high => 0.42,
  };

  /// The glow's width for a picture [width] points wide.
  static double edgeWidth(double width) => (width * KLiveStyle.fillLightEdge)
      .clamp(4.0, KLiveStyle.fillLightEdgeMax);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final shown = on && !level.isOff;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: shown
            ? CustomPaint(
                key: frameKey,
                painter: _EdgeGlowPainter(edgeOpacity(level)),
                child: const SizedBox.expand(),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _EdgeGlowPainter extends CustomPainter {
  const new(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final band = LiveFillLightFrame.edgeWidth(size.width);
    final edge = KLiveStyle.fillLight.withValues(alpha: opacity);
    final clear = KLiveStyle.fillLight.withValues(alpha: 0);
    void strip(Rect rect, Alignment from, Alignment to) => canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: from,
          end: to,
          colors: [edge, clear],
        ).createShader(rect),
    );
    final w = size.width;
    final h = size.height;
    strip(
      Rect.fromLTWH(0, 0, w, band),
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    strip(
      Rect.fromLTWH(0, h - band, w, band),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );
    strip(
      Rect.fromLTWH(0, 0, band, h),
      Alignment.centerLeft,
      Alignment.centerRight,
    );
    strip(
      Rect.fromLTWH(w - band, 0, band, h),
      Alignment.centerRight,
      Alignment.centerLeft,
    );
  }

  @override
  bool shouldRepaint(_EdgeGlowPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
