import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's launch animation (D63): Kabi hops in, then the "kabso."
/// wordmark rises under it. Geometry is in the animation's own canvas
/// (1080×1920), measured from the owner's preview video, so the wordmark
/// stays under Kabi at every screen ratio.
abstract final class KSplash {
  static const animationAsset = 'assets/splash/kabso_splash.json';

  /// Colours of the animation itself (its `bg` layer and Kabi's red), not
  /// theme colours: the launch looks the same in light and dark mode.
  static const background = Color(0xFF0F0F0F);
  static const red = Color(0xFFC2000B);

  /// The bundled wordmark face (Fredoka Bold, OFL).
  static const wordmarkFont = 'Fredoka';

  static const canvas = Size(1080, 1920);

  /// 180 frames at 60 fps; a test checks it against the asset.
  static const Duration animation = Duration(milliseconds: 3000);

  /// The last frame stays up this long before the app moves on.
  static const Duration hold = Duration(milliseconds: 350);
  static const Duration total = Duration(milliseconds: 3350);

  /// The wordmark fades in over frames 118–135 of 180.
  static const double wordmarkIn = 118 / 180;
  static const double wordmarkShown = 135 / 180;

  /// Measured in the preview's last frame: ink 436×122 at y 1318–1440, so
  /// 163 px Fredoka Bold at −4 px tracking. The line box sits 60 px above
  /// the ink (measured on a capture of this screen).
  static const wordmarkTop = 1258.0;
  static const wordmarkSize = 163.0;
  static const wordmarkTracking = -4.0;

  /// Distance the wordmark rises while fading in.
  static const wordmarkRise = 36.0;
}

/// Launch screen: plays the launch animation (with the voice, D63) while
/// the stored session is restored. The router leaves it once both are done;
/// if the restore failed, the error state replaces the animation.
class SplashScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const animationKey = Key('splash.animation');
  static const wordmarkKey = Key('splash.wordmark');
  static const loadingKey = Key('splash.loading');

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KSplash.total,
  );

  /// Lottie progress: the animation runs, then holds its last frame.
  late final Animation<double> _progress = _controller.drive(
    CurveTween(
      curve: Interval(
        0,
        KSplash.animation.inMicroseconds / KSplash.total.inMicroseconds,
      ),
    ),
  );

  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _progress,
    curve: const Interval(
      KSplash.wordmarkIn,
      KSplash.wordmarkShown,
      curve: Curves.easeOut,
    ),
  );

  var _started = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start(LottieComposition _) {
    if (_started || !mounted) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: show the last frame for the hold, without the voice.
      _controller.value = 1 - _holdFraction;
      _controller.forward();
      return;
    }
    // Voice and animation start together so the hops match the voice.
    unawaited(ref.read(splashVoiceProvider).play());
    _controller.forward();
  }

  static double get _holdFraction =>
      KSplash.hold.inMicroseconds / KSplash.total.inMicroseconds;

  void _finish() {
    if (!mounted) return;
    ref.read(splashIntroProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final introDone = ref.watch(splashIntroProvider);
    final state = ref.watch(sessionControllerProvider);

    if (introDone && state is AuthRestoreFailed) {
      return Scaffold(
        body: SafeArea(
          child: FailureErrorState(
            title: l10n.splashRestoreFailed,
            failure: state.failure,
            onRetry: () =>
                ref.read(sessionControllerProvider.notifier).restore(),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Material, not a bare ColoredBox: text needs a Material ancestor.
      child: Material(
        color: KSplash.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: l10n.brandSemanticLabel,
              image: true,
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox.fromSize(
                    size: KSplash.canvas,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Lottie.asset(
                            KSplash.animationAsset,
                            key: SplashScreen.animationKey,
                            controller: _progress,
                            frameRate: FrameRate.max,
                            fit: BoxFit.fill,
                            onLoaded: _start,
                            errorBuilder: (_, _, _) {
                              // Never keep the app on a broken animation.
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _finish(),
                              );
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        Positioned(
                          top: KSplash.wordmarkTop,
                          left: 0,
                          right: 0,
                          child: AnimatedBuilder(
                            animation: _wordmark,
                            builder: (_, child) => Opacity(
                              opacity: _wordmark.value,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  (1 - _wordmark.value) * KSplash.wordmarkRise,
                                ),
                                child: child,
                              ),
                            ),
                            child: const _Wordmark(
                              key: SplashScreen.wordmarkKey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The animation is over but the session is still restoring.
            if (introDone && state is AuthRestoring)
              Align(
                alignment: const Alignment(0, 0.8),
                child: Semantics(
                  label: l10n.loading,
                  child: const SizedBox.square(
                    key: SplashScreen.loadingKey,
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "kabso." — a Latin brand mark, always left-to-right.
class _Wordmark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'kabso'),
          TextSpan(
            text: '.',
            style: TextStyle(color: KSplash.red),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      softWrap: false,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: KSplash.wordmarkFont,
        fontSize: KSplash.wordmarkSize,
        fontWeight: FontWeight.w700,
        letterSpacing: KSplash.wordmarkTracking,
        color: Colors.white,
      ),
    );
  }
}
