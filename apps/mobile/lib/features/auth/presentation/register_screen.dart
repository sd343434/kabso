import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/auth_failures.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/registration_flow.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const emailKey = Key('register.email');
  static const usernameKey = Key('register.username');
  static const displayNameKey = Key('register.displayName');
  static const passwordKey = Key('register.password');
  static const submitKey = Key('register.submit');
  static const usernameStatusKey = Key('register.usernameStatus');
  static const usernameLostKey = Key('register.usernameLost');
  static const codeNoticeKey = Key('register.codeNotice');

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  /// Server-reported field errors, cleared when the field changes.
  final Map<AuthField, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    // Returning from the code screen ("Change email" or a lost username):
    // the form comes back filled (PHASE1_1_SCREENS §1.1).
    final draft = ref.read(registrationFlowProvider);
    if (draft != null) {
      _email.text = draft.email;
      _username.text = draft.username;
      _displayName.text = draft.displayName;
      _password.text = draft.password;
      if (draft.usernameLost) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showUsernameLost(draft.username);
        });
      }
    }
    _displayName.addListener(_onDisplayNameChanged);
  }

  void _onDisplayNameChanged() => setState(() {});

  void _showUsernameLost(String username) {
    ref.read(usernameAvailabilityProvider.notifier).markTaken(username);
  }

  @override
  void dispose() {
    _displayName.removeListener(_onDisplayNameChanged);
    _email.dispose();
    _username.dispose();
    _displayName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearServerError(AuthField field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors.remove(field));
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _serverErrors.clear();
    });
    final valid = _formKey.currentState?.validate() ?? false;
    final status = ref.read(usernameAvailabilityProvider);
    if (!valid || status is UsernameTaken) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _email.text,
          password: _password.text,
          username: _username.text,
          displayName: _displayName.text,
        );
    if (!mounted) return;
    if (ok) {
      // 202: code entry. The draft keeps the form for "Change email".
      // maybeOf: the screen is also hosted without a router (widget tests).
      await GoRouter.maybeOf(context)?.push(AppRoutes.registerCode);
      return;
    }

    final submission = ref.read(authControllerProvider);
    if (submission is! SubmissionFailed) return;
    final failure = submission.failure;
    final l10n = context.l10n;
    setState(() {
      for (final MapEntry(key: field, value: issue)
          in failure.authFieldIssues.entries) {
        // EMAIL_TAKEN is never mapped to a field (v1.2, D24).
        _serverErrors[field] = failure.code == ErrorCode.usernameTaken
            ? l10n.errorUsernameTaken
            : serverIssueMessage(l10n, field, issue);
      }
    });
    if (failure.code == ErrorCode.usernameTaken) {
      ref
          .read(usernameAvailabilityProvider.notifier)
          .markTaken(AuthValidators.normalizeUsername(_username.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final submission = ref.watch(authControllerProvider);
    final submitting = submission is SubmissionInProgress;
    final usernameStatus = ref.watch(usernameAvailabilityProvider);
    final draft = ref.watch(registrationFlowProvider);
    ref.listen(registrationFlowProvider, (previous, next) {
      if (next != null && next.usernameLost && previous?.usernameLost != true) {
        _showUsernameLost(next.username);
      }
    });
    final displayNameLength = AuthValidators.displayNameLength(
      _displayName.text,
    );

    // A failure that maps to a field is shown on that field only.
    final generalFailure =
        submission is SubmissionFailed && submission.failure.authFields.isEmpty
        ? submission.failure
        : null;

    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      actions: [AuthLanguageSwitch(enabled: !submitting)],
      child: RetryCountdown(
        key: ObjectKey(submission),
        failure: submission is SubmissionFailed ? submission.failure : null,
        builder: (context, remaining) => Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (draft?.usernameLost ?? false) ...[
                KInlineMessage(
                  key: RegisterScreen.usernameLostKey,
                  message: l10n.errUsernameTakenDuringVerify,
                ),
                const SizedBox(height: KSpacing.lg),
              ] else if (generalFailure != null) ...[
                FailureBanner(failure: generalFailure, remaining: remaining),
                const SizedBox(height: KSpacing.lg),
              ],
              KTextField(
                fieldKey: RegisterScreen.emailKey,
                controller: _email,
                label: l10n.registerEmailLabel,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                textDirection: TextDirection.ltr,
                maxLength: AuthRules.emailMax,
                enabled: !submitting,
                errorText: _serverErrors[AuthField.email],
                onChanged: (_) => _clearServerError(AuthField.email),
                validator: (v) => validationMessage(
                  l10n,
                  AuthValidators.email(v),
                  formatMessage: l10n.validationEmailInvalid,
                ),
              ),
              const SizedBox(height: KSpacing.lg),
              KTextField(
                fieldKey: RegisterScreen.usernameKey,
                controller: _username,
                label: l10n.registerUsernameLabel,
                helperText: l10n.registerUsernameHelper,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                textDirection: TextDirection.ltr,
                maxLength: AuthRules.usernameMax,
                inputFormatters: [_LowerCaseFormatter()],
                enabled: !submitting,
                errorText: _serverErrors[AuthField.username],
                status: _UsernameStatusLine(
                  key: RegisterScreen.usernameStatusKey,
                  status: usernameStatus,
                  // After the first submit the field's own validator shows the
                  // same reason as errorText; don't show it twice.
                  showInvalid: _autovalidate == AutovalidateMode.disabled,
                ).orNullIfHidden(),
                onChanged: (value) {
                  _clearServerError(AuthField.username);
                  if (draft?.usernameLost ?? false) {
                    ref
                        .read(registrationFlowProvider.notifier)
                        .acknowledgeUsernameLost();
                  }
                  ref
                      .read(usernameAvailabilityProvider.notifier)
                      .onChanged(value);
                },
                validator: (v) => usernameIssueMessage(
                  l10n,
                  AuthValidators.usernameIssue(
                    AuthValidators.normalizeUsername(v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.lg),
              KTextField(
                fieldKey: RegisterScreen.displayNameKey,
                controller: _displayName,
                label: l10n.registerDisplayNameLabel,
                helperText: l10n.registerDisplayNameHelper,
                // Graphemes, not UTF-16 units; no silent truncation (§2).
                counterText: l10n.displayNameCounter(displayNameLength),
                counterIsError: displayNameLength > AuthRules.displayNameMax,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                enabled: !submitting,
                errorText: _serverErrors[AuthField.displayName],
                onChanged: (_) => _clearServerError(AuthField.displayName),
                validator: (v) => displayNameIssueMessage(
                  l10n,
                  AuthValidators.displayNameIssue(v),
                ),
              ),
              const SizedBox(height: KSpacing.lg),
              KTextField(
                fieldKey: RegisterScreen.passwordKey,
                controller: _password,
                label: l10n.registerPasswordLabel,
                helperText: l10n.registerPasswordHelper,
                obscure: true,
                showPasswordLabel: l10n.passwordShow,
                hidePasswordLabel: l10n.passwordHide,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                textDirection: TextDirection.ltr,
                maxLength: AuthRules.passwordMax,
                enabled: !submitting,
                errorText: _serverErrors[AuthField.password],
                onChanged: (_) => _clearServerError(AuthField.password),
                onSubmitted: (_) async {
                  if (remaining == Duration.zero) await _submit();
                },
                validator: (v) =>
                    validationMessage(l10n, AuthValidators.password(v)),
              ),
              const SizedBox(height: KSpacing.xl),
              KButton(
                key: RegisterScreen.submitKey,
                label: l10n.registerSubmit,
                loading: submitting,
                // Disabled while a Retry-After countdown runs (QA-007).
                onPressed: remaining > Duration.zero ? null : _submit,
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                l10n.registerCodeNotice,
                key: RegisterScreen.codeNoticeKey,
                style: context.textStyles.caption,
              ),
              const SizedBox(height: KSpacing.xs),
              Text(l10n.registerTerms, style: context.textStyles.caption),
              const SizedBox(height: KSpacing.lg),
              AuthSwitchPrompt(
                question: l10n.registerHaveAccount,
                action: l10n.registerSignIn,
                onPressed: () {
                  // Leaving the flow to Login clears the in-memory draft.
                  ref.read(registrationFlowProvider.notifier).clear();
                  context.go(AppRoutes.login);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsernameStatusLine extends StatelessWidget {
  const new({required this.status, required this.showInvalid, super.key});

  final UsernameStatus status;
  final bool showInvalid;

  Widget? orNullIfHidden() => switch (status) {
    UsernameIdle() => null,
    UsernameInvalid() when !showInvalid => null,
    _ => this,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final (IconData? icon, Color color, String text) = switch (status) {
      UsernameChecking() => (null, p.textSecondary, l10n.usernameChecking),
      UsernameAvailable(:final username) => (
        Icons.check_circle_rounded,
        p.success,
        l10n.usernameAvailable(username),
      ),
      UsernameTaken(:final username) => (
        Icons.cancel_rounded,
        p.error,
        l10n.usernameTaken(username),
      ),
      UsernameInvalid(:final issue) => (
        Icons.error_outline_rounded,
        p.error,
        usernameIssueMessage(l10n, issue) ?? '',
      ),
      // Check failed: neutral hint, submit still allowed (server decides).
      UsernameUnknown() => (
        Icons.info_outline,
        p.textSecondary,
        l10n.usernameCheckFailed,
      ),
      UsernameIdle() => (null, p.textSecondary, ''),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (icon == null)
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: KSpacing.xs),
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
}

/// Usernames are lowercase (CONVENTIONS.md §6); lowercase as the user types.
class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toLowerCase());
}
