import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/splash_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

/// Kabi, the owner's mascot (D64), cut from the launch animation: the last
/// frames (smile, blink, smile) play once when it appears, then it rests on
/// the last frame. The animation's background, ground shadow and sparkles
/// are hidden, so it stands on whatever surface holds it.
///
/// Its own colours never change; place it on a dark surface
/// ([KSplash.background] or a dark-theme surface), as in the animation.
class KabiMascot extends StatefulWidget {
  const new({super.key});

  /// Kabi's box in the 1080×1920 canvas at the last frame (antenna tips to
  /// feet), measured on the owner's preview video.
  static const Rect canvasRect = Rect.fromLTRB(270, 520, 810, 1170);
  static double get aspectRatio => canvasRect.width / canvasRect.height;

  /// The idle segment: frames 156–180 of 180.
  static const double idleFrom = 156 / 180;
  static const Duration idle = Duration(milliseconds: 400);

  @override
  State<KabiMascot> createState() => _KabiMascotState();
}

class _KabiMascotState extends State<KabiMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KabiMascot.idle,
    lowerBound: KabiMascot.idleFrom,
  )..value = 1;

  static final _delegates = LottieDelegates(
    values: [
      for (final layer in const [
        'bg',
        'ground',
        'spark0',
        'spark1',
        'spark2',
        'spark3',
        'spark4',
        'spark5',
      ])
        ValueDelegate.transformOpacity(<String>[layer], value: 0),
    ],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loaded(LottieComposition _) {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: KabiMascot.idleFrom);
  }

  @override
  Widget build(BuildContext context) {
    const rect = KabiMascot.canvasRect;
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: KabiMascot.aspectRatio,
        child: FittedBox(
          child: SizedBox(
            width: rect.width,
            height: rect.height,
            child: Stack(
              children: [
                Positioned(
                  left: -rect.left,
                  top: -rect.top,
                  width: KSplash.canvas.width,
                  height: KSplash.canvas.height,
                  child: Lottie.asset(
                    KSplash.animationAsset,
                    controller: _controller,
                    delegates: _delegates,
                    frameRate: FrameRate.max,
                    fit: BoxFit.fill,
                    onLoaded: _loaded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kabi standing on the bottom edge of its parent, with [visible] of its
/// height showing (the rest is cut off by that edge).
class KabiPeek extends StatelessWidget {
  const new({required this.width, super.key, this.visible = 0.78});

  final double width;
  final double visible;

  @override
  Widget build(BuildContext context) {
    final height = width / KabiMascot.aspectRatio;
    // A fixed box, so intrinsic sizing (IntrinsicHeight, scroll views)
    // measures what is shown, not the unscaled animation canvas.
    return SizedBox(
      width: width,
      height: height * visible,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: height,
          child: SizedBox(
            width: width,
            height: height,
            child: const KabiMascot(),
          ),
        ),
      ),
    );
  }
}

/// The dark stage Kabi stands on: the launch background in the light theme
/// (so it reads as Kabi's own world on a white page), the raised surface in
/// the dark theme.
Color kabiStageColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? KSplash.background
    : context.palette.surfaceRaised;
