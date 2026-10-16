import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/registration_flow.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/features/auth/presentation/widgets/code_field.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// "Check your email": enter the 8-digit registration code
/// (PHASE1_1_SCREENS §1.2–1.4, contract v1.2 `register/verify`).
class RegisterCodeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const codeFieldKey = Key('code.field');
  static const submitKey = Key('code.submit');
  static const resendKey = Key('code.resend');
  static const statusKey = Key('code.status');
  static const changeEmailKey = Key('code.changeEmail');
  static const logInKey = Key('code.logIn');

  /// Resend cooldown after each 202.
  static const resendCooldown = Duration(seconds: 60);

  /// Local "may have expired" hint (server is authoritative).
  static const codeLifetime = Duration(minutes: 30);

  /// From this many consecutive `TOKEN_INVALID`, the stronger copy shows.
  static const repeatedFailures = 3;

  @override
  ConsumerState<RegisterCodeScreen> createState() => _RegisterCodeScreenState();
}

class _RegisterCodeScreenState extends ConsumerState<RegisterCodeScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  final _formatter = CodeInputFormatter();

  bool _verifying = false;
  bool _resending = false;

  /// Banner failure of the last verify (429 / 503 / network / unknown).
  AppFailure? _failure;

  /// Status-line failure of the last resend (e.g. 429).
  AppFailure? _resendFailure;
  DateTime? _resendBlockedUntil;

  bool _codeInvalid = false;
  int _invalidCount = 0;
  bool _pasteInvalid = false;
  bool _maybeExpired = false;

  /// The code the server rejected; not auto-submitted again until edited.
  String? _rejected;

  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(registrationFlowProvider);
    if (draft == null) {
      // Opened without a registration in progress (e.g. after a restart).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.register);
      });
      return;
    }
    _armExpiry(draft.codeSentAt);
  }

  void _armExpiry(DateTime sentAt) {
    _expiryTimer?.cancel();
    final left = sentAt
        .add(RegisterCodeScreen.codeLifetime)
        .difference(clock.now());
    _maybeExpired = left <= Duration.zero;
    if (!_maybeExpired) {
      _expiryTimer = Timer(left, () {
        if (mounted) setState(() => _maybeExpired = true);
      });
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _codeInvalid = false;
      _resendFailure = null;
      if (value != _rejected) _rejected = null;
      _pasteInvalid =
          _formatter.lastEditWasPaste && !_formatter.lastPasteWasValid;
    });
    final autoSubmit =
        value.length == kRegistrationCodeLength &&
        _rejected == null &&
        !_pasteInvalid;
    if (autoSubmit) unawaited(_verify());
  }

  Future<void> _verify() async {
    final draft = ref.read(registrationFlowProvider);
    final code = _code.text;
    if (draft == null || _verifying) return;
    if (code.length != kRegistrationCodeLength) return;
    setState(() {
      _verifying = true;
      _failure = null;
      _codeInvalid = false;
      _pasteInvalid = false;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .verifyRegistration(email: draft.email, code: code);
      if (!mounted) return;
      final l10n = context.l10n;
      ref.read(registrationFlowProvider.notifier).clear();
      KSnack.success(context, l10n.codeWelcome);
      // The router guard replaces the auth stack with the shell (Home).
      ref.read(sessionControllerProvider.notifier).signedIn(user);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      switch (failure.code) {
        case ErrorCode.tokenInvalid:
          setState(() {
            _verifying = false;
            _codeInvalid = true;
            _invalidCount++;
            _rejected = code;
            // The next keystroke replaces the whole code.
            _code.selection = TextSelection(
              baseOffset: 0,
              extentOffset: code.length,
            );
          });
          _focus.requestFocus();
        case ErrorCode.usernameTaken:
          // Race: someone took the username. Back to Register (§1.4).
          ref.read(registrationFlowProvider.notifier).usernameLost();
          _backToRegister();
        case ErrorCode.validationFailed:
          setState(() {
            _verifying = false;
            _pasteInvalid = true;
          });
        // Rate limit, busy, offline/timeout, unexpected: banner.
        // ignore: no_default_cases
        default:
          setState(() {
            _verifying = false;
            _failure = failure;
          });
      }
    }
  }

  Future<void> _resend() async {
    final draft = ref.read(registrationFlowProvider);
    if (draft == null || _resending) return;
    setState(() {
      _resending = true;
      _resendFailure = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resendRegistrationCode(draft.email);
      if (!mounted) return;
      final now = clock.now();
      ref.read(registrationFlowProvider.notifier).codeResent(now);
      _code.clear();
      setState(() {
        _resending = false;
        _codeInvalid = false;
        _invalidCount = 0;
        _rejected = null;
        _pasteInvalid = false;
        _resendBlockedUntil = null;
        _armExpiry(now);
      });
      _focus.requestFocus();
      KSnack.info(context, context.l10n.codeResent);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      setState(() {
        _resending = false;
        _resendFailure = failure;
        if (failure is ServerFailure && hasRetryCountdown(failure)) {
          _resendBlockedUntil = clock.now().add(failure.retryAfter!);
        }
      });
    }
  }

  void _backToRegister() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.register);
    }
  }

  void _logIn(String email) {
    ref.read(registrationFlowProvider.notifier).clear();
    ref.read(loginPrefillProvider.notifier).identifier = email;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = ref.watch(registrationFlowProvider);
    if (draft == null) return const Scaffold();

    final cooldownUntil = draft.codeSentAt.add(
      RegisterCodeScreen.resendCooldown,
    );
    final blockedUntil =
        _resendBlockedUntil != null &&
            _resendBlockedUntil!.isAfter(cooldownUntil)
        ? _resendBlockedUntil
        : cooldownUntil;

    return AuthScaffold(
      title: l10n.codeTitle,
      showBack: true,
      onBack: _backToRegister,
      backLabel: l10n.codeChangeEmail,
      // Email inside a bidi isolate (it is LTR in any language).
      subtitleWidget: Text(
        l10n.codeBody('\u2068${draft.email}\u2069'),
        style: context.textStyles.body.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
      child: RetryCountdown(
        key: ObjectKey(_failure),
        failure: _failure,
        builder: (context, remaining) {
          final blocked = remaining > Duration.zero;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: RegisterCodeScreen.changeEmailKey,
                  onPressed: _verifying ? null : _backToRegister,
                  child: Text(l10n.codeChangeEmail),
                ),
              ),
              const SizedBox(height: KSpacing.xl),
              CodeField(
                fieldKey: RegisterCodeScreen.codeFieldKey,
                controller: _code,
                focusNode: _focus,
                formatter: _formatter,
                label: l10n.codeFieldLabel,
                hint: l10n.codeFieldHint,
                error: _codeInvalid,
                // 429: field and CTA disabled until the countdown ends.
                enabled:
                    !_verifying &&
                    !(blocked && _failure?.code == ErrorCode.rateLimited),
                onChanged: _onChanged,
              ),
              const SizedBox(height: KSpacing.sm),
              DeadlineCountdown(
                until: _resendBlockedUntil,
                builder: (context, left) => _status(context, l10n, left),
              ),
              if (_failure != null) ...[
                const SizedBox(height: KSpacing.lg),
                FailureBanner(failure: _failure!, remaining: remaining),
              ],
              const SizedBox(height: KSpacing.xxl),
              ListenableBuilder(
                listenable: _code,
                builder: (context, _) => KButton(
                  key: RegisterCodeScreen.submitKey,
                  label: l10n.codeSubmit,
                  loading: _verifying,
                  onPressed:
                      _code.text.length == kRegistrationCodeLength && !blocked
                      ? _verify
                      : null,
                ),
              ),
              const SizedBox(height: KSpacing.md),
              DeadlineCountdown(
                until: blockedUntil,
                builder: (context, left) {
                  final waiting = left > Duration.zero;
                  final emphasize =
                      !waiting &&
                      _invalidCount >= RegisterCodeScreen.repeatedFailures;
                  return KButton(
                    key: RegisterCodeScreen.resendKey,
                    label: waiting
                        ? l10n.codeResendIn(KFormat.countdown(_ceil(left)))
                        : l10n.codeResend,
                    variant: emphasize
                        ? KButtonVariant.primary
                        : KButtonVariant.secondary,
                    loading: _resending,
                    onPressed: waiting || _verifying ? null : _resend,
                  );
                },
              ),
              const SizedBox(height: KSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.codeHaveAccount,
                    style: context.textStyles.body.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  TextButton(
                    key: RegisterCodeScreen.logInKey,
                    onPressed: _verifying ? null : () => _logIn(draft.email),
                    child: Text(l10n.codeLogIn),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Status line (live region): error or hint, in priority order.
  Widget _status(
    BuildContext context,
    AppLocalizations l10n,
    Duration resendWait,
  ) {
    final p = context.palette;
    final resendFailure = _resendFailure;
    final String text;
    final Color color;
    final IconData? icon;
    if (_pasteInvalid) {
      (text, color, icon) = (
        l10n.codePasteInvalid,
        p.error,
        Icons.error_outline_rounded,
      );
    } else if (_codeInvalid) {
      (text, color, icon) = (
        _invalidCount >= RegisterCodeScreen.repeatedFailures
            ? l10n.errCodeInvalidRepeated
            : l10n.errCodeInvalid,
        p.error,
        Icons.error_outline_rounded,
      );
    } else if (resendFailure != null) {
      (text, color, icon) = (
        failureMessage(l10n, resendFailure, remaining: resendWait),
        p.error,
        Icons.error_outline_rounded,
      );
    } else if (_maybeExpired) {
      (text, color, icon) = (
        l10n.codeMaybeExpired,
        p.textPrimary,
        Icons.warning_amber_rounded,
      );
    } else {
      (text, color, icon) = (l10n.codeExpiryHint, p.textSecondary, null);
    }
    return Semantics(
      liveRegion: true,
      child: Row(
        key: RegisterCodeScreen.statusKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 16,
                color: icon == Icons.warning_amber_rounded ? p.warning : color,
              ),
            ),
            const SizedBox(width: KSpacing.xs),
          ],
          Expanded(
            child: Text(
              text,
              style: context.textStyles.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  static Duration _ceil(Duration d) =>
      Duration(seconds: (d.inMilliseconds + 999) ~/ 1000);
}
