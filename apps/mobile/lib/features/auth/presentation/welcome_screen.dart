import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/features/auth/presentation/onboarding.dart';
import 'package:kabso_live/features/auth/presentation/splash_screen.dart';
import 'package:kabso_live/features/auth/presentation/widgets/kabso_motion.dart';
import 'package:kabso_live/features/debug/demo_entry.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's animated welcome screen (D64), integrated from the owner's
/// `kabso_welcome_screen.dart`, shown on the first signed-out launch only
/// (D65): a tilted wall of content cards drifting
/// behind Kabi, who drops in, hovers and waves, with orbiting feature
/// chips, floating hearts and comment bubbles; then the headline, "Let's
/// start" (the join screen) and "I have an account · Log in".
///
/// Changes from the supplied file, for the project rules: copy comes from
/// l10n (Arabic and English, direction from the locale); Baloo Bhaijaan 2
/// and Fredoka are bundled (OFL) instead of fetched by `google_fonts`;
/// card and chip glyphs come from the owner's icon set (D56); decorations
/// are hidden from screen readers; the motion stops after [KWelcome.motion]
/// (battery) and is skipped with reduced motion.
abstract final class KWelcome {
  static const Color red = KSplash.red;
  static const Color ink = KSplash.background;
  static const background = Color(0xFF0A0A0A);
  static const card = Color(0xFF1C1C1C);
  static const hotRed = Color(0xFFFF4A55);

  /// Arabic and Latin display face of this screen (OFL, bundled).
  static const font = 'Baloo Bhaijaan 2';

  /// The motion runs this long, then the transient decorations (hearts,
  /// comments, ripples, sparkles) fade out and everything rests.
  static const double motion = 20;
  static const double fadeOut = 0.6;

  /// With reduced motion the screen is drawn once at this moment, after
  /// every entrance has finished, without the transient decorations.
  static const double rest = 2.6;

  /// Kabi's area: drawn at [heroDesign] and scaled down to fit; it counts
  /// as [heroMinHeight] when the screen decides whether to scroll.
  static const Size heroDesign = Size(340, 380);
  static const double heroMinHeight = 200;
}

TextStyle _baloo(
  double size,
  FontWeight weight, {
  Color color = Colors.white,
  double? height,
}) => TextStyle(
  fontFamily: KWelcome.font,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

TextStyle _fredoka(
  double size, {
  Color color = Colors.white,
  double? tracking,
}) => TextStyle(
  fontFamily: KSplash.wordmarkFont,
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: color,
  letterSpacing: tracking,
);

Widget _rise(double t, double delay, Widget child, {double dy = 40}) {
  final p = motionProgress(t, delay, .7);
  return Opacity(
    opacity: p,
    child: Transform.translate(offset: Offset(0, (1 - p) * dy), child: child),
  );
}

/// The moment of the animation and how visible the transient decorations
/// are (1 while moving, fading to 0 at rest).
@immutable
class _Frame {
  const new(this.t, this.transient);

  final double t;
  final double transient;
}

// ───────────────────────── screen ─────────────────────────

/// First screen when signed out (D64).
class WelcomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const signUpKey = Key('welcome.signUp');
  static const logInKey = Key('welcome.logIn');
  static const heroKey = Key('welcome.hero');

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final _frame = ValueNotifier<_Frame>(const _Frame(0, 1));
  late final Ticker _ticker = createTicker(_tick);
  var _decided = false;

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    final transient = 1 - motionProgress(t, KWelcome.motion, KWelcome.fadeOut);
    _frame.value = _Frame(math.min(t, KWelcome.motion), transient);
    if (transient == 0) _ticker.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    // The first launch has now shown welcome; later ones go to login (D65).
    // After this frame: providers cannot change while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(welcomeSeenProvider.notifier).markSeen();
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _frame.value = const _Frame(KWelcome.rest, 0);
    } else {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: KWelcome.background,
        body: ValueListenableBuilder<_Frame>(
          valueListenable: _frame,
          builder: (context, frame, _) {
            final t = frame.t;
            return Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  child: RepaintBoundary(
                    child: _Wall(t: t, live: l10n.liveBadge),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x400A0A0A),
                        Color(0x8C0A0A0A),
                        KWelcome.background,
                      ],
                      stops: [0, .34, .6],
                    ),
                  ),
                ),
                SafeArea(
                  // Scrolls only when the content is taller than the
                  // screen (large text scales); the hero takes the rest.
                  child: LayoutBuilder(
                    builder: (context, viewport) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewport.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _rise(t, .1, _TopBar(t: t)),
                                Expanded(
                                  child: FixedIntrinsicHeight(
                                    height: KWelcome.heroMinHeight,
                                    child: ExcludeSemantics(
                                      child: _Hero(
                                        key: WelcomeScreen.heroKey,
                                        frame: frame,
                                      ),
                                    ),
                                  ),
                                ),
                                _Headline(t: t),
                                const SizedBox(height: 18),
                                _rise(
                                  t,
                                  1.7,
                                  _StartButton(
                                    t: t,
                                    label: l10n.welcomeStart,
                                    onTap: () => context.push(AppRoutes.join),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _rise(
                                  t,
                                  1.8,
                                  TextButton(
                                    key: WelcomeScreen.logInKey,
                                    onPressed: () =>
                                        context.push(AppRoutes.login),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: l10n.welcomeHaveAccount,
                                            style: _baloo(17, FontWeight.w600),
                                          ),
                                          TextSpan(
                                            text: l10n.loginSubmit,
                                            style: _baloo(
                                              17,
                                              FontWeight.w800,
                                              color: KWelcome.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                // D86: test builds only.
                                const DemoEntryButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── top bar ─────────────────────────

class _TopBar extends StatelessWidget {
  const new({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          label: l10n.brandSemanticLabel,
          header: true,
          excludeSemantics: true,
          child: Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'kabso'),
                TextSpan(
                  text: '.',
                  style: TextStyle(color: KWelcome.red),
                ),
              ],
            ),
            style: _fredoka(26, tracking: -.5),
            textDirection: TextDirection.ltr,
          ),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xCC0F0F0F),
              border: Border.all(color: const Color(0xFF333333)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: 1 - .75 * motionWave(motionLoop(t, 1.1)),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2D3A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.welcomeLiveChip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _baloo(13, FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────── moving wall of content cards ─────────────

enum _K {
  play,
  live,
  kabi,
  eq,
  heart,
  kabiRed,
  mic,
  live2,
  grid,
  radio,
  kabiWhite,
  blank,
}

class _Wall extends StatelessWidget {
  const new({required this.t, required this.live});

  final double t;

  /// The "LIVE" mark on the live cards.
  final String live;

  static const List<List<_K>> _cols = [
    [_K.play, _K.live, _K.kabi, _K.eq],
    [_K.heart, _K.kabiRed, _K.mic, _K.live2],
    [_K.grid, _K.radio, _K.kabiWhite, _K.blank],
  ];
  static const _periods = [18.0, 22.0, 26.0];
  static const _up = [true, false, true];

  static double _h(_K k) => switch (k) {
    _K.play => 200,
    _K.live => 150,
    _K.kabi => 230,
    _K.eq => 170,
    _K.heart => 170,
    _K.kabiRed => 240,
    _K.mic => 160,
    _K.live2 => 200,
    _K.grid => 210,
    _K.radio => 160,
    _K.kabiWhite => 230,
    _K.blank => 150,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          children: [
            Positioned(
              left: -w * .23,
              top: -h * .17,
              width: w * 1.46,
              height: h * 1.3,
              child: Transform.rotate(
                angle: degrees(-12),
                child: Opacity(
                  opacity: .9,
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 14),
                        Expanded(child: _column(i)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _column(int i) {
    final kinds = _cols[i];
    final total = kinds.fold<double>(0, (s, k) => s + _h(k) + 14);
    final shift = (t / _periods[i] % 1) * total;
    final off = _up[i] ? -shift : shift - total;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: Offset(0, off),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < 3; r++)
                for (final k in kinds) _cardFor(k),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kabi() => Align(
    alignment: Alignment.bottomCenter,
    child: Transform.translate(
      offset: const Offset(0, 10),
      child: SizedBox(
        width: 150,
        height: 150 * 98 / 88,
        child: CustomPaint(painter: KabiPainter(t: 0, animate: false)),
      ),
    ),
  );

  Widget _liveBadge({bool avatar = true}) => Stack(
    children: [
      Positioned(
        top: 12,
        left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: KWelcome.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            live,
            style: _fredoka(
              12,
              tracking: 1,
            ).copyWith(fontFamilyFallback: const [KWelcome.font]),
          ),
        ),
      ),
      if (avatar)
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
    ],
  );

  Widget _eq() => Center(
    child: SizedBox(
      height: 50,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var j = 0; j < 4; j++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 7,
              height: 50 * (.3 + .7 * motionWave(((t - j * .2) / .9) % 1)),
              decoration: BoxDecoration(
                color: j.isEven ? KWelcome.red : Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _cardFor(_K k) {
    var bg = KWelcome.card;
    Widget? child;
    switch (k) {
      case _K.play:
        bg = KWelcome.red;
        child = const Center(
          child: AppIcon(AppIcons.play, size: 64, color: Colors.white),
        );
      case _K.live:
        child = _liveBadge();
      case _K.live2:
        child = _liveBadge(avatar: false);
      case _K.kabi:
      case _K.kabiWhite:
        bg = Colors.white;
        child = _kabi();
      case _K.kabiRed:
        bg = KWelcome.red;
        child = _kabi();
      case _K.eq:
        child = _eq();
      case _K.heart:
        child = const Center(
          child: AppIcon(AppIcons.heartFilled, size: 54, color: KWelcome.red),
        );
      case _K.mic:
        bg = Colors.white;
        child = const Center(
          child: AppIcon(AppIcons.mic, size: 52, color: KWelcome.red),
        );
      case _K.grid:
        child = const Center(
          child: AppIcon(AppIcons.gridFilled, size: 52, color: Colors.white),
        );
      case _K.radio:
        bg = KWelcome.red;
        child = const Center(
          child: AppIcon(AppIcons.liveTv, size: 54, color: Colors.white),
        );
      case _K.blank:
        child = null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        height: _h(k),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      ),
    );
  }
}

// ───────────────────────── hero: Kabi + glow + orbit ─────────────────────────

class _Hero extends StatelessWidget {
  const new({required this.frame, super.key});

  final _Frame frame;

  double get t => frame.t;

  @override
  Widget build(BuildContext context) {
    final fx = frame.transient;
    // Drop-in with squash and stretch.
    final d = ((t - .2) / 1.25).clamp(0.0, 1.0);
    const at = [0.0, .55, .7, .85, 1.0];
    final dy = motionKeyframes(d, at, [-520, 0, -34, 0, 0]);
    final sx = motionKeyframes(d, at, [.9, 1.12, .96, 1.04, 1]);
    final sy = motionKeyframes(d, at, [1.1, .86, 1.05, .96, 1]);

    // Idle hover.
    final hv = motionProgress(t, 1.4, .6);
    final hu = motionLoop(t, 3.4, 1.5);
    final hy = -14 * hv * motionWave(hu);
    final hr = degrees(4 * hv * math.sin(2 * math.pi * hu));

    // A little "hello" wiggle every 4 s.
    final wr = degrees(
      motionKeyframes(
        motionLoop(t, 4, 2.4),
        [.72, .76, .8, .84, .88, .92],
        [0, -9, 8, -7, 5, 0],
      ),
    );

    final orbitIn = motionProgress(t, .9, 1, Curves.easeOutBack);
    final orbitRot = t / 16 * 2 * math.pi;
    final glow = motionWave(motionLoop(t, 2.6));

    // Drawn at its designed size and scaled down when the area is smaller.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox.fromSize(
        size: KWelcome.heroDesign,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (fx > 0)
              for (final delay in [1.4, 2.2])
                if (t > delay)
                  Opacity(
                    opacity: fx,
                    child: _ring(
                      Curves.easeOut.transform(motionLoop(t, 2.4, delay)),
                    ),
                  ),
            Opacity(
              opacity: .95 - .2 * glow,
              child: Transform.scale(
                scale: 1 + .08 * glow,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: const BoxDecoration(
                    color: KWelcome.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x73C2000B),
                        blurRadius: 90,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Orbiting feature chips.
            Opacity(
              opacity: orbitIn.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: degrees(-120) * (1 - orbitIn),
                child: Transform.scale(
                  scale: .3 + .7 * orbitIn,
                  child: SizedBox(
                    width: 310,
                    height: 310,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (var i = 0; i < 4; i++)
                          Transform.translate(
                            offset: Offset.fromDirection(
                              orbitRot - math.pi / 2 + i * math.pi / 2,
                              155,
                            ),
                            child: _chip(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Ground shadow.
            Transform.translate(
              offset: const Offset(0, 118),
              child: Opacity(
                opacity:
                    (.8 + hy / 14 * .4).clamp(0.0, 1.0) *
                    motionProgress(t, .9, .4),
                child: Transform.scale(
                  scale: 1 + hy / 14 * .3,
                  child: Container(
                    width: 150,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Kabi.
            Transform.translate(
              offset: Offset(0, dy + hy),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(sx, sy, 1),
                child: Transform.rotate(
                  angle: hr + wr,
                  alignment: const Alignment(0, .8),
                  child: SizedBox(
                    width: 230,
                    height: 256,
                    child: CustomPaint(
                      painter: KabiPainter(t: t, animate: fx > 0),
                    ),
                  ),
                ),
              ),
            ),
            if (fx > 0) ...[
              _spark(const Offset(118, -116), 30, Colors.white, 1.6, fx),
              _spark(const Offset(-126, 94), 22, KWelcome.red, 2.3, fx),
              _spark(const Offset(-116, -66), 18, Colors.white, 1.9, fx),
              Positioned(
                left: -6,
                bottom: 10,
                width: 60,
                height: 260,
                child: Opacity(
                  opacity: fx,
                  child: _Hearts(t: t),
                ),
              ),
              Positioned(
                right: -6,
                top: 110,
                width: 150,
                height: 200,
                child: Opacity(
                  opacity: fx,
                  child: _Comments(t: t),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ring(double u) => Opacity(
    opacity: .9 * (1 - u),
    child: Transform.scale(
      scale: .6 + 1.3 * u,
      child: Container(
        width: 230,
        height: 230,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: KWelcome.red, width: 3),
        ),
      ),
    ),
  );

  Widget _chip(int i) {
    const specs = [
      (KWelcome.red, AppIcons.play, Colors.white, false),
      (Colors.white, AppIcons.heartFilled, KWelcome.red, false),
      (KWelcome.card, AppIcons.mic, Colors.white, true),
      (Colors.white, AppIcons.giftFilled, KWelcome.red, false),
    ];
    final (bg, icon, fg, border) = specs[i];
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: border ? Border.all(color: KWelcome.red, width: 2) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: AppIcon(icon, color: fg, size: 24),
    );
  }

  Widget _spark(Offset at, double size, Color color, double delay, double fx) {
    final v = t < delay ? 0.0 : motionWave(motionLoop(t, 2.2, delay)) * fx;
    return Transform.translate(
      offset: at,
      child: Transform.rotate(
        angle: degrees(90 * v),
        child: Transform.scale(
          scale: v,
          child: CustomPaint(
            size: Size(size, size),
            painter: _SparkPainter(color),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── live hearts ─────────────────────────

class _Hearts extends StatelessWidget {
  const new({required this.t});

  final double t;

  static const List<(double, double, Color, double)> _specs = [
    (1.8, 30.0, KWelcome.red, 0.0),
    (2.4, 22.0, Colors.white, 26.0),
    (3.0, 26.0, Color(0xFFFF4A55), 10.0),
    (3.5, 18.0, Colors.white, 32.0),
    (4.1, 28.0, KWelcome.red, 4.0),
  ];

  @override
  Widget build(BuildContext context) {
    const at = [0.0, .12, .5, 1.0];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (delay, size, color, left) in _specs)
          if (t > delay)
            () {
              final u = Curves.easeOut.transform(motionLoop(t, 3, delay));
              return Positioned(
                left: left,
                bottom: 0,
                child: Opacity(
                  opacity: motionKeyframes(u, at, [0, 1, 1, 0]).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(
                      motionKeyframes(u, at, [0, 0, 14, -8]),
                      motionKeyframes(u, at, [0, -20, -130, -250]),
                    ),
                    child: Transform.rotate(
                      angle: degrees(motionKeyframes(u, at, [0, 0, 12, -10])),
                      child: Transform.scale(
                        scale: motionKeyframes(u, at, [.3, 1.15, 1, .8]),
                        child: AppIcon(
                          AppIcons.heartFilled,
                          size: size,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }(),
      ],
    );
  }
}

// ───────────────────────── comment bubbles ─────────────────────────

/// Illustrative comment bubbles (no names, no real users), hidden from
/// screen readers with the rest of the hero.
class _Comments extends StatelessWidget {
  const new({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final specs = [
      (2.0, l10n.welcomeComment1, KWelcome.red),
      (3.6, l10n.welcomeComment2, Colors.white),
      (5.2, l10n.welcomeComment3, const Color(0xFFFF6A72)),
    ];
    const at = [0.0, .08, .7, 1.0];
    return ClipRect(
      child: Stack(
        children: [
          for (final (delay, text, color) in specs)
            if (t > delay)
              () {
                final u = Curves.easeOut.transform(motionLoop(t, 4.8, delay));
                return Positioned(
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: motionKeyframes(u, at, [
                      0,
                      1,
                      1,
                      0,
                    ]).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(
                        motionKeyframes(u, at, [-30, 0, 0, 0]),
                        motionKeyframes(u, at, [0, 0, -70, -130]),
                      ),
                      child: Transform.scale(
                        scale: motionKeyframes(u, at, [.8, 1, 1, 1]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xD91C1C1C),
                            border: Border.all(color: const Color(0xFF333333)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(text, style: _baloo(13, FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }(),
        ],
      ),
    );
  }
}

// ───────────────────────── headline ─────────────────────────

class _Headline extends StatelessWidget {
  const new({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final big = _baloo(46, FontWeight.w800, height: 1.1);
    final marker = math.max(
      .001,
      motionProgress(t, 1.35, .6, Curves.easeInOutCubic),
    );
    final start = AlignmentDirectional.centerStart.resolve(
      Directionality.of(context),
    );
    return Semantics(
      header: true,
      label:
          '${l10n.welcomeHeadline1} ${l10n.welcomeHeadline2} '
          '${l10n.welcomeHeadline3}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            children: [
              _word(l10n.welcomeHeadline1, 1.15, big),
              _word(l10n.welcomeHeadline2, 1.3, big),
            ],
          ),
          _rise(
            t,
            1.3,
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -6,
                  right: -6,
                  bottom: 4,
                  height: 22,
                  child: Transform(
                    alignment: start,
                    transform: Matrix4.diagonal3Values(marker, 1, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: KWelcome.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                Text(l10n.welcomeHeadline3, style: big),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _rise(
            t,
            1.5,
            Text(
              l10n.welcomeBody,
              style: _baloo(
                16,
                FontWeight.w600,
                color: const Color(0xFFBDBDBD),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _word(String s, double delay, TextStyle style) {
    final p = motionProgress(t, delay, .6, Curves.easeOutBack);
    return Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 30 * (1 - p)),
        child: Transform.rotate(
          angle: degrees(6) * (1 - p),
          child: Transform.scale(
            scale: .8 + .2 * p,
            child: Text(s, style: style),
          ),
        ),
      ),
    );
  }
}

// ───────────── start button (shine + breathe + nudge) ─────────────

class _StartButton extends StatelessWidget {
  const new({required this.t, required this.label, required this.onTap});

  final double t;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = t > 2.6 ? motionWave(motionLoop(t, 2.4, 2.6)) : 0.0;
    final su = motionLoop(t, 3, 2.5);
    final shine = su < .6
        ? -1.4
        : -1.4 + 4.8 * Curves.easeInOut.transform((su - .6) / .4);
    final nudge = -6 * motionWave(motionLoop(t, 1.2));

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(255, 255, 255, .35 * (1 - b)),
              spreadRadius: 10 * b,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: WelcomeScreen.signUpKey,
            onTap: onTap,
            excludeFromSemantics: true,
            child: Builder(
              builder: (context) {
                return Stack(
                  children: [
                    // The shine: 40 % of the width with its left edge at
                    // shine × 40 % of it. No LayoutBuilder, so the screen
                    // can still size itself intrinsically when it scrolls.
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment(2 * .4 * shine / .6 - 1, 0),
                        child: FractionallySizedBox(
                          widthFactor: .4,
                          heightFactor: 1,
                          child: Transform(
                            transform: Matrix4.skewX(-.35),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0x00C2000B),
                                    Color(0x2EC2000B),
                                    Color(0x00C2000B),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 24,
                        end: 7,
                        top: 7,
                        bottom: 7,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: _baloo(
                                20,
                                FontWeight.w800,
                                color: KWelcome.ink,
                              ),
                            ),
                          ),
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: KWelcome.red,
                              shape: BoxShape.circle,
                            ),
                            child: Transform.translate(
                              offset: Offset(nudge, 0),
                              // Mirrors with the direction: forward in both.
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Kabi (play-eye) painter ─────────────────────────

/// Kabi drawn from the owner's approved geometry (viewBox 6 -2 88 98). Use a
/// size with ratio 88:98, e.g. Size(230, 256).
class KabiPainter extends CustomPainter {
  new({required this.t, this.animate = true});

  final double t;
  final bool animate;

  static final Path _body = Path()
    ..moveTo(50, 28)
    ..cubicTo(71, 28, 85, 41, 85, 59)
    ..cubicTo(85, 77, 70, 89, 50, 89)
    ..cubicTo(30, 89, 15, 77, 15, 59)
    ..cubicTo(15, 41, 29, 28, 50, 28)
    ..close();
  static final Path _antennae = Path()
    ..moveTo(38, 34)
    ..cubicTo(35, 24, 30, 17, 25, 12)
    ..moveTo(62, 34)
    ..cubicTo(65, 24, 70, 17, 75, 12);
  static final Path _tri = Path()
    ..moveTo(58.5, 55)
    ..lineTo(46, 47.8)
    ..lineTo(46, 62.2)
    ..close();
  static final Path _smile = Path()
    ..moveTo(44, 79)
    ..quadraticBezierTo(50, 83, 56, 79);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 88)
      ..translate(-6, 2);

    final ink = Paint()..color = KWelcome.ink;
    final line = Paint()
      ..color = KWelcome.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(_antennae, line..strokeWidth = 5.5);

    // Antenna tips glow.
    final g1 = animate ? motionWave(motionLoop(t, 1.2)) : 0.0;
    final g2 = animate ? motionWave(motionLoop(t + .6, 1.2)) : 0.0;
    canvas
      ..drawCircle(
        const Offset(24, 11),
        6,
        Paint()..color = Color.lerp(KWelcome.red, KWelcome.hotRed, g1)!,
      )
      ..drawCircle(
        const Offset(76, 11),
        6,
        Paint()..color = Color.lerp(KWelcome.red, KWelcome.hotRed, g2)!,
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(38, 88), width: 18, height: 10),
        ink,
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(62, 88), width: 18, height: 10),
        ink,
      )
      ..drawPath(_body, Paint()..color = Colors.white);

    // Eye: blink.
    final blink = animate
        ? motionKeyframes(motionLoop(t, 4.2, 2.2), [.46, .5, .54], [1, .08, 1])
        : 1.0;
    canvas
      ..save()
      ..translate(50, 55)
      ..scale(1, blink)
      ..translate(-50, -55)
      ..drawCircle(const Offset(50, 55), 18, ink);

    // Ripple ring from the play button.
    if (animate && t > 1.4) {
      final ru = motionLoop(t, 1.6, 1.4);
      canvas.drawCircle(
        const Offset(50, 55),
        14.5 * (.7 + .55 * Curves.easeOut.transform(ru)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = KWelcome.red.withAlpha((255 * (1 - ru)).round()),
      );
    }

    // Play triangle: looks around and pulses.
    const lookAt = [0.0, .18, .24, .40, .46, .62, .68, .82, 1.0];
    final lu = animate ? motionLoop(t, 6, 2) : 0.0;
    final lx = motionKeyframes(lu, lookAt, [0, 0, -3.5, -3.5, 3, 3, 0, 0, 0]);
    final ly = motionKeyframes(lu, lookAt, [0, 0, -1, -1, 1, 1, -2, -2, 0]);
    final pulse = animate
        ? motionKeyframes(
            motionLoop(t, 1.6, 1.4),
            [0, .1, .2, .3, .4, 1],
            [1, 1.28, .92, 1.1, 1, 1],
          )
        : 1.0;
    canvas
      ..save()
      ..translate(51 + lx, 55 + ly)
      ..scale(pulse)
      ..translate(-51, -55)
      ..drawPath(_tri, Paint()..color = KWelcome.red)
      ..drawPath(
        _tri,
        Paint()
          ..color = KWelcome.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();

    // Glint.
    final gl = animate ? motionWave(motionLoop(t, 1.6)) : 0.0;
    canvas
      ..drawCircle(
        const Offset(42.5, 47.5),
        3.4 * (1 - .4 * gl),
        Paint()..color = Colors.white.withAlpha((255 * (1 - .5 * gl)).round()),
      )
      ..restore() // blink
      ..drawPath(_smile, line..strokeWidth = 3.5);
    final cheek = Paint()..color = KWelcome.red.withAlpha(140);
    canvas
      ..drawCircle(const Offset(28, 66), 4.5, cheek)
      ..drawCircle(const Offset(72, 66), 4.5, cheek)
      ..restore();
  }

  @override
  bool shouldRepaint(KabiPainter old) => old.t != t || old.animate != animate;
}

class _SparkPainter extends CustomPainter {
  new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Path()
      ..moveTo(12, 1)
      ..quadraticBezierTo(12, 12, 23, 12)
      ..quadraticBezierTo(12, 12, 12, 23)
      ..quadraticBezierTo(12, 12, 1, 12)
      ..quadraticBezierTo(12, 12, 12, 1)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.color != color;
}
