import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/registration_flow.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/welcome_screen.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/features/auth/presentation/widgets/kabso_motion.dart';
import 'package:kabso_live/features/debug/demo_entry.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The login palette of the owner's `kabso_login_screen.dart` (D65), light
/// and dark after the app theme.
@immutable
class KLoginPalette {
  const new({
    required this.background,
    required this.ink,
    required this.muted,
    required this.field,
    required this.fieldLine,
    required this.line,
    required this.lens,
    required this.lensRim,
    required this.halo,
    required this.googleBackground,
    required this.appleBackground,
    required this.appleInk,
  });

  final Color background;
  final Color ink;
  final Color muted;
  final Color field;
  final Color fieldLine;
  final Color line;
  final Color lens;
  final Color lensRim;
  final Color halo;
  final Color googleBackground;
  final Color appleBackground;
  final Color appleInk;

  static const light = KLoginPalette(
    background: Color(0xFFFFFFFF),
    ink: Color(0xFF0F0F0F),
    muted: Color(0xFF6B6B6B),
    field: Color(0xFFF4F4F4),
    fieldLine: Color(0xFFEBEBEB),
    line: Color(0xFF0F0F0F),
    lens: Color(0xFF0F0F0F),
    lensRim: Color(0xFF0F0F0F),
    halo: Color(0x1AC2000B),
    googleBackground: Color(0xFFFFFFFF),
    appleBackground: Color(0xFF0F0F0F),
    appleInk: Color(0xFFFFFFFF),
  );

  static const dark = KLoginPalette(
    background: Color(0xFF0F0F0F),
    ink: Color(0xFFFFFFFF),
    muted: Color(0xFFA0A0A0),
    field: Color(0xFF1A1A1A),
    fieldLine: Color(0xFF262626),
    line: Color(0xFFFFFFFF),
    lens: Color(0xFF000000),
    lensRim: Color(0xFF2A2A2A),
    halo: Color(0x47C2000B),
    googleBackground: Color(0xFF1A1A1A),
    appleBackground: Color(0xFFFFFFFF),
    appleInk: Color(0xFF0F0F0F),
  );

  static KLoginPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Login geometry (D65).
abstract final class KLogin {
  static const Color red = KWelcome.red;
  static const Color hot = KWelcome.hotRed;

  /// Kabi's face: design space 390 × 320 at the screen's width.
  static const double faceAspect = 320 / 390;
  static const double maxFaceWidth = 440;
  static const double inset = 26;
  static const double fieldRadius = 18;
  static const double buttonRadius = 20;
  static const double motion = 20;
  static const double rest = 1.5;
}

TextStyle _baloo(double size, FontWeight weight, Color color, {double? h}) =>
    TextStyle(
      fontFamily: KWelcome.font,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: h,
    );

/// Login in the owner's design (D65): Kabi's face drops in at the top
/// (blinking, looking around, antennae swaying), "Ready to go live?", the
/// two fields, Google and Apple, the red button with a light sweep, and
/// "No account? Create one".
///
/// The behaviour is the earlier login's: validation, server errors with
/// Error IDs, Retry-After countdowns, the ended-session banner, the
/// language switch and the email prefill from the code screen. Changes
/// from the supplied file: the identifier is "email or username" (the
/// contract has no phone login); Google and Apple are disabled and marked
/// "Soon" (proposal CP-002); the button says "Log in" (the copy rules
/// T2/T3 forbid "كابسو" in Arabic and "!"); copy from l10n; bundled fonts;
/// the motion stops after [KLogin.motion] and is skipped with reduced
/// motion.
class LoginScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const identifierKey = Key('login.identifier');
  static const passwordKey = Key('login.password');
  static const submitKey = Key('login.submit');
  static const faceKey = Key('login.face');
  static const createAccountKey = Key('login.createAccount');

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin, MotionClock {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  double get motionSeconds => KLogin.motion;

  @override
  double get restSeconds => KLogin.rest;

  @override
  void initState() {
    super.initState();
    // e.g. "Log in" from the registration code screen prefills the email.
    final prefill = ref.read(loginPrefillProvider);
    if (prefill != null) {
      _identifier.text = prefill;
      // Consume it after the first frame (providers can't change mid-build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(loginPrefillProvider.notifier).identifier = null;
      });
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(identifier: _identifier.text, password: _password.text);
  }

  /// The owner's field style, applied to the design-system fields.
  ThemeData _fieldTheme(BuildContext context, KLoginPalette lp) {
    final theme = Theme.of(context);
    final p = context.palette;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(KLogin.fieldRadius),
      borderSide: BorderSide(color: color, width: width),
    );
    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: lp.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: border(lp.fieldLine, 1.5),
        enabledBorder: border(lp.fieldLine, 1.5),
        disabledBorder: border(lp.fieldLine, 1.5),
        focusedBorder: border(KLogin.red, 2),
        errorBorder: border(p.error, 1.5),
        focusedErrorBorder: border(p.error, 2),
        labelStyle: _baloo(16, FontWeight.w600, lp.muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lp = KLoginPalette.of(context);
    final submission = ref.watch(authControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final submitting = submission is SubmissionInProgress;

    final endedReason = session is Unauthenticated ? session.reason : null;
    final banner = switch (endedReason) {
      ErrorCode.accountSuspended => l10n.accountSuspendedBanner,
      ErrorCode.authRefreshInvalid => l10n.sessionEndedBanner,
      _ => null,
    };
    Widget rise(double delay, Widget child) =>
        MotionRise(time: time, delay: delay, child: child);
    final title = _baloo(34, FontWeight.w800, lp.ink, h: 1.15);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lp == KLoginPalette.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: lp.background,
        body: LayoutBuilder(
          builder: (context, viewport) {
            final faceWidth = viewport.maxWidth.clamp(0.0, KLogin.maxFaceWidth);
            return Stack(
              children: [
                // Soft red halo behind Kabi.
                Positioned(
                  top: -60,
                  left: viewport.maxWidth / 2 - 150,
                  child: IgnorePointer(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [lp.halo, lp.halo.withAlpha(0)],
                          stops: const [0, .7],
                        ),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          Center(
                            child: ExcludeSemantics(
                              child: SizedBox(
                                key: LoginScreen.faceKey,
                                width: faceWidth,
                                height: faceWidth * KLogin.faceAspect,
                                child: CustomPaint(
                                  painter: KabiFacePainter(time, lp),
                                ),
                              ),
                            ),
                          ),
                          SafeArea(
                            bottom: false,
                            child: SizedBox(
                              height: kToolbarHeight,
                              child: Row(
                                children: [
                                  if (Navigator.canPop(context))
                                    BackButton(color: lp.ink)
                                  else
                                    const SizedBox(width: KSpacing.md),
                                  const Spacer(),
                                  AuthLanguageSwitch(enabled: !submitting),
                                  const SizedBox(width: KSpacing.md),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KLogin.inset,
                            ),
                            child: Theme(
                              data: _fieldTheme(context, lp),
                              child: _form(
                                context,
                                lp: lp,
                                rise: rise,
                                title: title,
                                banner: banner,
                                submission: submission,
                                submitting: submitting,
                              ),
                            ),
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
    );
  }

  Widget _form(
    BuildContext context, {
    required KLoginPalette lp,
    required Widget Function(double, Widget) rise,
    required TextStyle title,
    required String? banner,
    required FormSubmission submission,
    required bool submitting,
  }) {
    final l10n = context.l10n;
    return RetryCountdown(
      key: ObjectKey(submission),
      failure: submission is SubmissionFailed ? submission.failure : null,
      builder: (context, remaining) => AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rise(
                .5,
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.loginTitleLead),
                        TextSpan(
                          text: l10n.loginTitleAccent,
                          style: title.copyWith(color: KLogin.red),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: title,
                  ),
                ),
              ),
              rise(
                .6,
                Text(
                  l10n.loginSubtitle,
                  textAlign: TextAlign.center,
                  style: _baloo(15, FontWeight.w600, lp.muted),
                ),
              ),
              const SizedBox(height: 16),
              if (banner != null && submission is! SubmissionFailed) ...[
                KInlineMessage(message: banner),
                const SizedBox(height: KSpacing.md),
              ],
              if (submission is SubmissionFailed) ...[
                FailureBanner(
                  failure: submission.failure,
                  remaining: remaining,
                ),
                const SizedBox(height: KSpacing.md),
              ],
              rise(
                .7,
                KTextField(
                  fieldKey: LoginScreen.identifierKey,
                  controller: _identifier,
                  label: l10n.loginIdentifierLabel,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  textDirection: TextDirection.ltr,
                  maxLength: AuthRules.identifierMax,
                  enabled: !submitting,
                  validator: (v) =>
                      validationMessage(l10n, AuthValidators.identifier(v)),
                ),
              ),
              const SizedBox(height: 12),
              rise(
                .8,
                KTextField(
                  fieldKey: LoginScreen.passwordKey,
                  controller: _password,
                  label: l10n.loginPasswordLabel,
                  obscure: true,
                  showPasswordLabel: l10n.passwordShow,
                  hidePasswordLabel: l10n.passwordHide,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  textDirection: TextDirection.ltr,
                  maxLength: AuthRules.loginPasswordMax,
                  enabled: !submitting,
                  onSubmitted: (_) async {
                    if (remaining == Duration.zero) await _submit();
                  },
                  validator: (v) =>
                      validationMessage(l10n, AuthValidators.loginPassword(v)),
                ),
              ),
              const SizedBox(height: 6),
              rise(
                .85,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: submitting
                        ? null
                        : () => context.push(AppRoutes.forgotPassword),
                    child: Text(
                      l10n.loginForgotPassword,
                      style: _baloo(14, FontWeight.w700, KLogin.red),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              rise(.95, AuthSocialButtons(palette: lp)),
              const SizedBox(height: 16),
              rise(
                1.05,
                _ShineButton(
                  key: LoginScreen.submitKey,
                  time: time,
                  label: l10n.loginSubmit,
                  loading: submitting,
                  // Disabled while a Retry-After countdown runs (QA-007).
                  onTap: remaining > Duration.zero || submitting
                      ? null
                      : _submit,
                ),
              ),
              const SizedBox(height: 14),
              rise(
                1.15,
                Center(
                  child: TextButton(
                    key: LoginScreen.createAccountKey,
                    onPressed: () => context.go(AppRoutes.register),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${l10n.loginNoAccount} ',
                            style: _baloo(15, FontWeight.w600, lp.muted),
                          ),
                          TextSpan(
                            text: l10n.loginCreateAccount,
                            style: _baloo(15, FontWeight.w800, KLogin.red),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              // D86: test builds only.
              Center(child: DemoEntryButton(color: lp.muted)),
              SizedBox(height: 20 + MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }
}

/// The red button with a light sweep and a press scale (owner's design).
/// Disabled ([onTap] null) it fades; [loading] shows a spinner.
class _ShineButton extends StatefulWidget {
  const new({
    required this.time,
    required this.label,
    required this.onTap,
    super.key,
    this.loading = false,
  });

  final ValueListenable<double> time;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  State<_ShineButton> createState() => _ShineButtonState();
}

class _ShineButtonState extends State<_ShineButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      liveRegion: widget.loading,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 150),
          child: AnimatedOpacity(
            opacity: enabled || widget.loading ? 1 : .5,
            duration: const Duration(milliseconds: 150),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              decoration: BoxDecoration(
                color: KLogin.red,
                borderRadius: BorderRadius.circular(KLogin.buttonRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59C2000B),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KLogin.buttonRadius),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ValueListenableBuilder<double>(
                        valueListenable: widget.time,
                        builder: (_, t, _) {
                          final u = motionLoop(t, 3.2, 2);
                          final x = u < .65
                              ? -1.6
                              : -1.6 +
                                    5.8 *
                                        Curves.easeInOut.transform(
                                          (u - .65) / .35,
                                        );
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: .3,
                              heightFactor: 1,
                              child: FractionalTranslation(
                                translation: Offset(x, 0),
                                child: Transform(
                                  transform: Matrix4.skewX(-.35),
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0x00FFFFFF),
                                          Color(0x47FFFFFF),
                                          Color(0x00FFFFFF),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: widget.loading
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: _baloo(20, FontWeight.w800, Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kabi's face on the login screen (owner's design space 390 × 320): drops
/// in, antennae sway and glow, cheeks blush, the lens blinks and ripples,
/// the play-eye looks around and pulses, a smile.
class KabiFacePainter extends CustomPainter {
  new(this.time, this.palette) : super(repaint: time);

  final ValueListenable<double> time;
  final KLoginPalette palette;

  static final _antL = Path()
    ..moveTo(150, 100)
    ..cubicTo(140, 60, 120, 32, 92, 10);
  static final _antR = Path()
    ..moveTo(240, 100)
    ..cubicTo(250, 60, 270, 32, 298, 10);
  static final _tri = Path()
    ..moveTo(242, 178)
    ..lineTo(173, 138)
    ..lineTo(173, 218)
    ..close();
  static final _smile = Path()
    ..moveTo(178, 300)
    ..quadraticBezierTo(195, 312, 212, 300);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final p = palette;
    canvas
      ..save()
      ..scale(size.width / 390);

    // Drop-in.
    final d = (t / .9).clamp(0.0, 1.0);
    final dy = motionKeyframes(d, [0, .6, 1], [-120, 10, 0], Curves.easeOut);
    final sc = motionKeyframes(d, [0, .6, 1], [.9, 1.03, 1], Curves.easeOut);
    canvas
      ..translate(195, 160 + dy)
      ..scale(sc)
      ..translate(-195, -160);

    final line = Paint()
      ..color = p.line
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Antennae sway.
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
        ..rotate(degrees(6 * dir * motionWave(motionLoop(t, 2.6, delay))))
        ..translate(-pivot.dx, -pivot.dy)
        ..drawPath(path, line..strokeWidth = 14)
        ..drawCircle(
          tip,
          17,
          Paint()
            ..color = Color.lerp(
              KLogin.red,
              KLogin.hot,
              motionWave(motionLoop(t + delay * 2, 1.3)),
            )!,
        )
        ..restore();
    }

    antenna(_antL, const Offset(150, 100), const Offset(90, 8), -1, 0);
    antenna(_antR, const Offset(240, 100), const Offset(300, 8), 1, .3);

    // Cheeks.
    final blush = .45 + .35 * motionWave(motionLoop(t, 2.4));
    final blush2 = .45 + .35 * motionWave(motionLoop(t + 1.2, 2.4));
    canvas
      ..drawCircle(
        const Offset(48, 240),
        26,
        Paint()..color = KLogin.hot.withAlpha((255 * blush).round()),
      )
      ..drawCircle(
        const Offset(342, 240),
        26,
        Paint()..color = KLogin.hot.withAlpha((255 * blush2).round()),
      );

    // Lens and blink.
    final blink = motionKeyframes(
      motionLoop(t, 4.6, 1.6),
      [.44, .47, .50],
      [1, .06, 1],
    );
    canvas
      ..save()
      ..translate(195, 178)
      ..scale(1, blink)
      ..translate(-195, -178)
      ..drawCircle(const Offset(195, 178), 100, Paint()..color = p.lens)
      ..drawCircle(
        const Offset(195, 178),
        100,
        Paint()
          ..color = p.lensRim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );

    // Ripple.
    if (t > 1) {
      final u = Curves.easeOut.transform(motionLoop(t, 1.8, 1));
      canvas.drawCircle(
        const Offset(195, 178),
        80 * (.75 + .43 * u),
        Paint()
          ..color = KLogin.red.withAlpha((230 * (1 - u)).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }

    // The play-eye looks around and pulses.
    const at = [0.0, .15, .22, .38, .45, .60, .67, .82, 1.0];
    final lu = motionLoop(t, 6.5, 1.2);
    final lx = motionKeyframes(lu, at, [0, 0, -22, -22, 20, 20, 0, 0, 0]);
    final ly = motionKeyframes(lu, at, [0, 0, -6, -6, 4, 4, 14, 14, 0]);
    final pulse = motionKeyframes(
      motionLoop(t, 1.8, 1),
      [0, .12, .24, .36, 1],
      [1, 1.18, .94, 1, 1],
    );
    final gl = 1 - .45 * motionWave(motionLoop(t, 1.8));
    canvas
      ..save()
      ..translate(200.6 + lx, 178 + ly)
      ..scale(pulse)
      ..translate(-200.6, -178)
      ..drawPath(_tri, Paint()..color = KLogin.red)
      ..drawPath(
        _tri,
        Paint()
          ..color = KLogin.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore()
      ..drawCircle(
        const Offset(152, 136),
        18,
        Paint()..color = Colors.white.withAlpha((255 * gl).round()),
      )
      ..drawCircle(
        const Offset(232, 222),
        7,
        Paint()..color = Colors.white.withAlpha(128),
      )
      ..restore() // blink
      ..drawPath(_smile, line..strokeWidth = 8)
      ..restore();
  }

  @override
  bool shouldRepaint(KabiFacePainter old) =>
      old.palette != palette || old.time != time;
}

/// Google and Apple in the owner's style (D65). Neither works yet: the
/// contract has no social sign-in (proposal CP-002), so both are disabled,
/// marked "Soon" and say so to screen readers. The glyphs are Simple Icons
/// (CC0) placeholders; the providers' official button assets replace them
/// when CP-002 is implemented.
class AuthSocialButtons extends StatelessWidget {
  const new({required this.palette, super.key});

  static const googleKey = Key('auth.social.google');
  static const appleKey = Key('auth.social.apple');

  /// Width one button needs at text scale 1 (glyph, name, "Soon").
  static const double minHalfWidth = 150;

  final KLoginPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final google = _SocialButton(
      key: googleKey,
      icon: AppIcons.google,
      name: l10n.authProviderGoogle,
      background: palette.googleBackground,
      ink: palette.ink,
      border: palette.fieldLine,
    );
    final apple = _SocialButton(
      key: appleKey,
      icon: AppIcons.apple,
      name: l10n.authProviderApple,
      background: palette.appleBackground,
      ink: palette.appleInk,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side when each half fits its content; stacked on narrow
        // screens and large text scales.
        final half = (constraints.maxWidth - 10) / 2;
        final needed = MediaQuery.textScalerOf(context).scale(minHalfWidth);
        if (half >= needed) {
          return Row(
            children: [
              Expanded(child: google),
              const SizedBox(width: 10),
              Expanded(child: apple),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [google, const SizedBox(height: 10), apple],
        );
      },
    );
  }
}

class _SocialButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.name,
    required this.background,
    required this.ink,
    super.key,
    this.border,
  });

  final String icon;
  final String name;
  final Color background;
  final Color ink;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      enabled: false,
      label: l10n.authSocialSoonLabel(name),
      excludeSemantics: true,
      child: Opacity(
        opacity: .6,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: border == null
                ? null
                : Border.all(color: border!, width: 1.5),
          ),
          // Wraps at large text scales instead of overflowing.
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              AppIcon(icon, size: 20, color: ink),
              Text(name, style: _baloo(15, FontWeight.w800, ink)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: ink.withAlpha(90)),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  l10n.authSocialSoon,
                  style: _baloo(12, FontWeight.w600, ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
