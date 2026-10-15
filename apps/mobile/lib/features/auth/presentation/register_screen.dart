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
  void dispose() {
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
    if (ok || !mounted) return;

    final submission = ref.read(authControllerProvider);
    if (submission is! SubmissionFailed) return;
    final failure = submission.failure;
    final l10n = context.l10n;
    setState(() {
      for (final MapEntry(key: field, value: issue)
          in failure.authFieldIssues.entries) {
        _serverErrors[field] = switch (failure.code) {
          ErrorCode.emailTaken => l10n.errorEmailTaken,
          ErrorCode.usernameTaken => l10n.errorUsernameTaken,
          _ => serverIssueMessage(l10n, field, issue),
        };
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

    // A failure that maps to a field is shown on that field only.
    final generalFailure =
        submission is SubmissionFailed && submission.failure.authFields.isEmpty
        ? submission.failure
        : null;

    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      child: RetryCountdown(
        key: ObjectKey(submission),
        failure: submission is SubmissionFailed ? submission.failure : null,
        builder: (context, remaining) => Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (generalFailure != null) ...[
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
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: AuthRules.displayNameMax,
                enabled: !submitting,
                errorText: _serverErrors[AuthField.displayName],
                onChanged: (_) => _clearServerError(AuthField.displayName),
                validator: (v) =>
                    validationMessage(l10n, AuthValidators.displayName(v)),
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
              const SizedBox(height: KSpacing.lg),
              AuthSwitchPrompt(
                question: l10n.registerHaveAccount,
                action: l10n.registerSignIn,
                onPressed: () => context.go(AppRoutes.login),
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
