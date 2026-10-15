import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Requests a password reset. On success it always shows the same
/// "if an account exists…" confirmation (no account enumeration).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const emailKey = Key('forgot.email');
  static const submitKey = Key('forgot.submit');

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = AuthValidators.normalizeEmail(_email.text);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email);
    if (ok && mounted) setState(() => _sentTo = email);
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final submission = ref.watch(authControllerProvider);
    final submitting = submission is SubmissionInProgress;
    final sentTo = _sentTo;

    if (sentTo != null) {
      return AuthScaffold(
        showBack: true,
        title: l10n.forgotConfirmationTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KInlineMessage(
              isError: false,
              message: l10n.forgotConfirmationBody(sentTo),
            ),
            const SizedBox(height: KSpacing.xl),
            KButton(label: l10n.forgotBackToLogin, onPressed: _backToLogin),
          ],
        ),
      );
    }

    return AuthScaffold(
      showBack: true,
      title: l10n.forgotTitle,
      subtitle: l10n.forgotSubtitle,
      child: RetryCountdown(
        key: ObjectKey(submission),
        failure: submission is SubmissionFailed ? submission.failure : null,
        builder: (context, remaining) => Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (submission is SubmissionFailed) ...[
                FailureBanner(
                  failure: submission.failure,
                  remaining: remaining,
                ),
                const SizedBox(height: KSpacing.lg),
              ],
              KTextField(
                fieldKey: ForgotPasswordScreen.emailKey,
                controller: _email,
                label: l10n.forgotEmailLabel,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                textDirection: TextDirection.ltr,
                maxLength: AuthRules.emailMax,
                enabled: !submitting,
                onSubmitted: (_) async {
                  if (remaining == Duration.zero) await _submit();
                },
                validator: (v) => validationMessage(
                  l10n,
                  AuthValidators.email(v),
                  formatMessage: l10n.validationEmailInvalid,
                ),
              ),
              const SizedBox(height: KSpacing.xl),
              KButton(
                key: ForgotPasswordScreen.submitKey,
                label: l10n.forgotSubmit,
                loading: submitting,
                onPressed: remaining > Duration.zero ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
