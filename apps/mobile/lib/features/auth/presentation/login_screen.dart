import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const identifierKey = Key('login.identifier');
  static const passwordKey = Key('login.password');
  static const submitKey = Key('login.submit');

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final submission = ref.watch(authControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final submitting = submission is SubmissionInProgress;

    final endedReason = session is Unauthenticated ? session.reason : null;
    final banner = switch (endedReason) {
      ErrorCode.accountSuspended => l10n.accountSuspendedBanner,
      ErrorCode.authRefreshInvalid => l10n.sessionEndedBanner,
      _ => null,
    };

    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      child: RetryCountdown(
        key: ObjectKey(submission),
        failure: submission is SubmissionFailed ? submission.failure : null,
        builder: (context, remaining) => Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner != null && submission is! SubmissionFailed) ...[
                KInlineMessage(message: banner),
                const SizedBox(height: KSpacing.lg),
              ],
              if (submission is SubmissionFailed) ...[
                FailureBanner(
                  failure: submission.failure,
                  remaining: remaining,
                ),
                const SizedBox(height: KSpacing.lg),
              ],
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
              const SizedBox(height: KSpacing.lg),
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
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: submitting
                      ? null
                      : () => context.push(AppRoutes.forgotPassword),
                  child: Text(l10n.loginForgotPassword),
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: LoginScreen.submitKey,
                label: l10n.loginSubmit,
                loading: submitting,
                // Disabled while a Retry-After countdown runs (QA-007).
                onPressed: remaining > Duration.zero ? null : _submit,
              ),
              const SizedBox(height: KSpacing.lg),
              AuthSwitchPrompt(
                question: l10n.loginNoAccount,
                action: l10n.loginCreateAccount,
                onPressed: () => context.go(AppRoutes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
