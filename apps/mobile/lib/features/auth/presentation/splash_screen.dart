import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/features/auth/presentation/splash_video.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The launch screen's constants.
abstract final class KSplash {
  /// D156: the owner's launch video (a gift box bursts open, Kabi pops out,
  /// "kabso • LIVE"), re-encoded for the app: 720×1280, 30 fps, H.264 High,
  /// AAC mono 96 kbps (assets/splash/PROVENANCE.md).
  static const videoAsset = 'assets/splash/kabso_splash.mp4';

  /// The video's last frame: the reduced-motion still and the fallback when
  /// the video cannot play.
  static const endFrameAsset = 'assets/splash/kabso_splash_end.webp';

  /// Sampled from the video's first frame (the median of its outer 40 px,
  /// RGB 19/16/14). The native launch windows use the same colour
  /// (`@color/launch_background`, LaunchScreen.storyboard), so there is no
  /// flash between the system splash and the video.
  static const videoBackground = Color(0xFF13100E);

  static const videoSize = Size(720, 1280);
  static const Duration videoLength = Duration(milliseconds: 6600);

  /// The Skip button appears this long after the video starts.
  static const Duration skipAfter = Duration(milliseconds: 500);

  /// Reduced motion: the last frame stays this long, instead of the video.
  static const Duration stillHold = Duration(milliseconds: 1500);

  /// A video that has not loaded by then is treated as failed.
  static const Duration loadTimeout = Duration(seconds: 3);

  /// A video that has not reported its end this long after its length has
  /// stalled: the app moves on anyway.
  static const Duration stallGrace = Duration(seconds: 2);

  // The D63 Lottie (Kabi hops in) is no longer the launch screen but stays
  // the welcome screen's mascot (KabiMascot), with its colours and font.

  static const animationAsset = 'assets/splash/kabso_splash.json';

  /// Colours of the Lottie itself (its `bg` layer and Kabi's red), not
  /// theme colours.
  static const background = Color(0xFF0F0F0F);
  static const red = Color(0xFFC2000B);

  /// The bundled wordmark face (Fredoka Bold, OFL).
  static const wordmarkFont = 'Fredoka';

  /// The Lottie's canvas.
  static const canvas = Size(1080, 1920);
}

enum _Phase { loading, video, still }

/// Launch screen (D156): plays the owner's launch video, with its sound
/// unless the app's sound effects are off or the phone is silent, while the
/// stored session is restored. It finishes when the video ends or is
/// skipped; the router then leaves for home or welcome. A session still
/// restoring keeps the last frame with a spinner; a failed restore shows its
/// error state. A video that cannot play falls back to its last frame at
/// once, and reduced motion shows that frame for [KSplash.stillHold].
class SplashScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const videoKey = Key('splash.video');
  static const stillKey = Key('splash.still');
  static const skipKey = Key('splash.skip');
  static const loadingKey = Key('splash.loading');

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  SplashVideoController? _video;

  /// Reduced motion: times the still (a controller, as D63 did, so the app
  /// settles through it like any animation).
  AnimationController? _hold;
  _Phase _phase = _Phase.loading;
  var _started = false;
  var _finished = false;
  var _showSkip = false;
  final _timers = <Timer>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: the last frame, silent, for a moment.
      _phase = _Phase.still;
      _hold = AnimationController(vsync: this, duration: KSplash.stillHold)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        })
        ..forward();
      return;
    }
    final video = _video = ref.read(splashVideoFactoryProvider)(
      KSplash.videoAsset,
    )..addListener(_onVideo);
    unawaited(_play(video));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _hold?.dispose();
    final video = _video;
    _video = null;
    if (video != null) {
      video.removeListener(_onVideo);
      unawaited(video.dispose());
    }
    super.dispose();
  }

  Future<void> _play(SplashVideoController video) async {
    try {
      // Asked while the video loads, so the sound costs no time.
      final soundOn = splashSoundOn(
        soundEffects: ref.read(soundEffectsProvider),
        silentMode: ref.read(deviceSilentModeProvider),
      );
      await video.initialize().timeout(KSplash.loadTimeout);
      if (!_current(video)) return;
      final sound = await soundOn.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => false,
      );
      if (!_current(video)) return;
      await video.setVolume(sound ? 1 : 0);
      if (!_current(video)) return;
      await video.play();
      if (!_current(video)) return;
      setState(() => _phase = _Phase.video);
      final state = video.state;
      final length = state.duration > Duration.zero
          ? state.duration
          : KSplash.videoLength;
      _timers
        ..add(
          Timer(KSplash.skipAfter, () {
            if (mounted && !_finished) setState(() => _showSkip = true);
          }),
        )
        ..add(Timer(length - state.position + KSplash.stallGrace, _finish));
    } on Object catch (error) {
      debugPrint('Launch video unavailable: $error');
      _fallBack();
    }
  }

  bool _current(SplashVideoController video) =>
      mounted && !_finished && identical(video, _video);

  void _onVideo() {
    final video = _video;
    if (video == null || _finished) return;
    final state = video.state;
    if (state.failed) {
      _fallBack();
    } else if (state.completed) {
      // Hold the last frame (the session may still be restoring).
      if (_phase == _Phase.loading) setState(() => _phase = _Phase.video);
      _finish();
    }
  }

  /// The video could not play: its last frame, and on with the app.
  void _fallBack() {
    if (!mounted || _finished) return;
    setState(() => _phase = _Phase.still);
    _finish();
  }

  void _skip() {
    unawaited(_video?.pause());
    _finish();
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    for (final t in _timers) {
      t.cancel();
    }
    setState(() => _showSkip = false);
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

    final video = _video;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Material, not a bare ColoredBox: text needs a Material ancestor.
      child: Material(
        color: KSplash.videoBackground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: l10n.brandSemanticLabel,
              image: true,
              child: ExcludeSemantics(
                child: switch (_phase) {
                  _Phase.loading => const SizedBox.expand(),
                  _Phase.video when video != null => _Cover(
                    key: SplashScreen.videoKey,
                    size: video.state.size.isEmpty
                        ? KSplash.videoSize
                        : video.state.size,
                    child: video.buildView(),
                  ),
                  _ => Image.asset(
                    KSplash.endFrameAsset,
                    key: SplashScreen.stillKey,
                    // Cover, centred: the same crop as the video.
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                },
              ),
            ),
            if (_showSkip)
              PositionedDirectional(
                top: MediaQuery.paddingOf(context).top + KMetrics.statusBarGap,
                end: 12,
                child: _SkipButton(label: l10n.splashSkip, onPressed: _skip),
              ),
            // The video is over but the session is still restoring.
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

/// [child] at [size], scaled to fill the screen and centred (the sides are
/// cropped on phones taller than 9:16).
class _Cover extends StatelessWidget {
  const new({required this.size, required this.child, super.key});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(size: size, child: child),
      ),
    );
  }
}

/// «تخطي» / "Skip": a small glass pill over the video.
class _SkipButton extends StatelessWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: SplashScreen.skipKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        minimumSize: const Size(64, 32),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(side: BorderSide(color: Color(0x40FFFFFF))),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label, maxLines: 1),
    );
  }
}
