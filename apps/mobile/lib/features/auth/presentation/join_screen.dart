import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/features/auth/presentation/welcome_screen.dart';
import 'package:kabso_live/features/auth/presentation/widgets/kabso_motion.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Join geometry and colours (D65, from the owner's
/// `kabso_signup_screen.dart`; the screen is always light, as designed).
abstract final class KJoin {
  static const background = Color(0xFFFFF6F4);
  static const Color red = KWelcome.red;
  static const Color ink = KWelcome.ink;
  static const body = Color(0xFF555555);

  /// Kabi's design space is 390 × 300 at the screen's width.
  static const double kabiAspect = 300 / 390;

  /// The text starts this far down (share of the screen height).
  static const double titleTop = .24;

  /// Kabi's area counts as this tall when deciding whether to scroll.
  static const double kabiMinHeight = 140;

  static const double motion = 20;
  static const double rest = 2;
}

/// "Create account" or "Log in" (D65), after the welcome screen on the
/// first launch: playful circles, the pitch, two buttons and Kabi peeking
/// up from the bottom with a blink, a look around and swaying antennae.
///
/// Changes from the supplied file, for the project rules: copy from l10n
/// (Arabic and English; the decorations mirror with the direction);
/// bundled fonts; buttons with keys and button semantics; the motion stops
/// after [KJoin.motion] and is skipped with reduced motion; the column
/// scrolls at large text scales.
class JoinScreen extends StatefulWidget {
  const new({super.key});

  static const createKey = Key('join.create');
  static const logInKey = Key('join.logIn');
  static const kabiKey = Key('join.kabi');

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen>
    with SingleTickerProviderStateMixin, MotionClock {
  @override
  double get motionSeconds => KJoin.motion;

  @override
  double get restSeconds => KJoin.rest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const title = TextStyle(
      fontFamily: KWelcome.font,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      color: KJoin.ink,
      height: 1.12,
    );
    Widget rise(double delay, Widget child) =>
        MotionRise(time: time, delay: delay, child: child);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: KJoin.background,
        body: LayoutBuilder(
          builder: (context, viewport) => Stack(
            children: [
              ExcludeSemantics(child: _Shapes(time: time)),
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: viewport.maxHeight * KJoin.titleTop,
                                ),
                                rise(
                                  .35,
                                  Semantics(
                                    header: true,
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${l10n.joinTitleLead}\n',
                                          ),
                                          TextSpan(
                                            text: l10n.joinTitleAccent,
                                            style: title.copyWith(
                                              color: KJoin.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      style: title,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                rise(
                                  .45,
                                  Text(
                                    l10n.joinBody,
                                    style: const TextStyle(
                                      fontFamily: KWelcome.font,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: KJoin.body,
                                      height: 1.55,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                rise(
                                  .55,
                                  _JoinButton(
                                    key: JoinScreen.createKey,
                                    label: l10n.joinCreate,
                                    filled: true,
                                    onTap: () =>
                                        context.push(AppRoutes.register),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                rise(
                                  .65,
                                  _JoinButton(
                                    key: JoinScreen.logInKey,
                                    label: l10n.loginSubmit,
                                    filled: false,
                                    onTap: () => context.push(AppRoutes.login),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        // Kabi takes what is left, down to the screen's
                        // bottom edge.
                        Expanded(
                          child: FixedIntrinsicHeight(
                            height: KJoin.kabiMinHeight,
                            child: ExcludeSemantics(
                              child: _PeekKabi(
                                key: JoinScreen.kabiKey,
                                time: time,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circles and the play mark at the top (the owner placed them for
/// Arabic; they mirror in English).
class _Shapes extends StatelessWidget {
  const new({required this.time});

  final ValueListenable<double> time;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: time,
    builder: (context, t, _) {
      Widget pop(double delay, Widget child) => Transform.scale(
        scale: motionProgress(t, delay, .6, Curves.easeOutBack).clamp(0.0, 2.0),
        child: child,
      );
      return Stack(
        children: [
          PositionedDirectional(
            top: -110,
            start: -70,
            child: pop(
              .05,
              Container(
                width: 290,
                height: 290,
                decoration: const BoxDecoration(
                  color: KJoin.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 36,
            end: 118,
            child: pop(
              .2,
              Transform.translate(
                offset: Offset(
                  -8 * motionWave(motionLoop(t, 5)),
                  10 * motionWave(motionLoop(t, 5)),
                ),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: KJoin.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 34,
            end: -46,
            child: pop(
              .3,
              Transform.translate(
                offset: Offset(
                  10 * motionWave(motionLoop(t, 6)),
                  -6 * motionWave(motionLoop(t, 6)),
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: KJoin.red, width: 14),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 200,
            end: 40,
            child: pop(
              .45,
              const AppIcon(AppIcons.play, color: KJoin.red, size: 40),
            ),
          ),
        ],
      );
    },
  );
}

class _JoinButton extends StatefulWidget {
  const new({
    required this.label,
    required this.filled,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? .97 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.filled ? KJoin.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: widget.filled
                ? null
                : Border.all(color: KJoin.red, width: 2.5),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: KWelcome.font,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: widget.filled ? Colors.white : KJoin.red,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Kabi peeking up from the bottom edge: drawn at the screen's width
/// (design space 390 × 300), standing on the bottom of its area; on short
/// screens its top stays under the buttons and the rest is cut off.
class _PeekKabi extends StatelessWidget {
  const new({required this.time, super.key});

  final ValueListenable<double> time;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, area) {
      final width = area.maxWidth;
      final height = width * KJoin.kabiAspect;
      return ClipRect(
        child: OverflowBox(
          alignment: area.maxHeight >= height
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          maxHeight: height,
          child: ValueListenableBuilder<double>(
            valueListenable: time,
            builder: (context, t, child) {
              // Peek in, then a slow bob.
              final pk = ((t - .5) / 1.1).clamp(0.0, 1.0);
              final peekY = motionKeyframes(
                pk,
                [0, .6, .8, 1],
                [320, -18, 6, 0],
                Curves.easeOut,
              );
              final bob = -8 * motionWave(motionLoop(t, 3, 1.6));
              return Transform.translate(
                offset: Offset(0, (peekY + bob) * width / 390 + 10),
                child: child,
              );
            },
            child: SizedBox(
              width: width,
              height: height,
              child: CustomPaint(painter: PeekKabiPainter(time)),
            ),
          ),
        ),
      );
    },
  );
}

/// The owner's Kabi peeking (design space 390 × 300): red body, blinking
/// lens, the play-eye looking around and pulsing, antennae swaying.
class PeekKabiPainter extends CustomPainter {
  new(this.time) : super(repaint: time);

  final ValueListenable<double> time;

  static final _antL = Path()
    ..moveTo(150, 104)
    ..cubicTo(142, 70, 126, 46, 104, 28);
  static final _antR = Path()
    ..moveTo(240, 104)
    ..cubicTo(248, 70, 264, 46, 286, 28);
  static final _body = Path()
    ..moveTo(195, 92)
    ..cubicTo(330, 92, 400, 160, 400, 260)
    ..lineTo(400, 320)
    ..lineTo(-10, 320)
    ..lineTo(-10, 260)
    ..cubicTo(-10, 160, 60, 92, 195, 92)
    ..close();
  static final _tri = Path()
    ..moveTo(234, 210)
    ..lineTo(177, 177)
    ..lineTo(177, 243)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas
      ..save()
      ..scale(size.width / 390);

    final line = Paint()
      ..color = KJoin.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;

    void antenna(
      Path path,
      Offset pivot,
      Offset tip,
      double dir,
      double delay,
    ) {
      canvas
        ..save()
        ..translate(pivot.dx, pivot.dy)
        ..rotate(degrees(8 * dir * motionWave(motionLoop(t, 2.4, delay))))
        ..translate(-pivot.dx, -pivot.dy)
        ..drawPath(path, line)
        ..drawCircle(tip, 14, Paint()..color = KJoin.red)
        ..restore();
    }

    antenna(_antL, const Offset(150, 104), const Offset(101, 25), -1, 0);
    antenna(_antR, const Offset(240, 104), const Offset(289, 25), 1, .3);

    final cheek = Paint()..color = const Color(0xB3FF4A55);
    canvas
      ..drawPath(_body, Paint()..color = KJoin.red)
      ..drawCircle(const Offset(62, 236), 22, cheek)
      ..drawCircle(const Offset(328, 236), 22, cheek);

    // Lens and blink.
    final blink = motionKeyframes(
      motionLoop(t, 4.6, 2),
      [.44, .47, .50],
      [1, .06, 1],
    );
    canvas
      ..save()
      ..translate(195, 210)
      ..scale(1, blink)
      ..translate(-195, -210)
      ..drawCircle(const Offset(195, 210), 82, Paint()..color = KJoin.ink)
      ..drawCircle(
        const Offset(195, 210),
        66,
        Paint()
          ..color = Colors.white.withAlpha(64)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

    const at = [0.0, .15, .22, .40, .48, .64, .72, .86, 1.0];
    final lu = motionLoop(t, 6.5, 1.8);
    final lx = motionKeyframes(lu, at, [0, 0, 18, 18, -18, -18, 0, 0, 0]);
    final ly = motionKeyframes(lu, at, [0, 0, -14, -14, -10, -10, -22, -22, 0]);
    final pulse = motionKeyframes(
      motionLoop(t, 1.8, 1.6),
      [0, .12, .24, .36, 1],
      [1, 1.18, .94, 1, 1],
    );
    canvas
      ..save()
      ..translate(199.8 + lx, 210 + ly)
      ..scale(pulse)
      ..translate(-199.8, -210)
      ..drawPath(_tri, Paint()..color = Colors.white)
      ..drawPath(
        _tri,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore()
      ..drawCircle(const Offset(160, 175), 15, Paint()..color = Colors.white)
      ..restore() // blink
      ..restore();
  }

  @override
  bool shouldRepaint(PeekKabiPainter old) => old.time != time;
}
