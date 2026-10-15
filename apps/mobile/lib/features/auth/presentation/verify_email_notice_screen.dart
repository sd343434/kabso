import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Shown right after registration: explains the verification email and
/// lets the user resend it (`POST /auth/email/resend`).
class VerifyEmailNoticeScreen extends ConsumerWidget {
  const new({super.key});

  static const resendKey = Key('verify.resend');
  static const continueKey = Key('verify.continue');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final submission = ref.watch(authControllerProvider);
    final submitting = submission is SubmissionInProgress;

    Future<void> resend() async {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .resendVerificationEmail();
      if (ok && context.mounted) KSnack.success(context, l10n.verifyResent);
    }

    void continueToApp() {
      ref.read(sessionControllerProvider.notifier).acknowledgeRegistration();
      context.go(AppRoutes.home);
    }

    return AuthScaffold(
      title: l10n.verifyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 56,
            color: context.palette.primary,
          ),
          const SizedBox(height: KSpacing.lg),
          Text(
            l10n.verifyBody(user?.email ?? ''),
            style: context.textStyles.body,
          ),
          const SizedBox(height: KSpacing.xl),
          if (submission is SubmissionFailed) ...[
            FailureBanner(failure: submission.failure),
            const SizedBox(height: KSpacing.lg),
          ],
          KButton(
            key: continueKey,
            label: l10n.verifyContinue,
            onPressed: submitting ? null : continueToApp,
          ),
          const SizedBox(height: KSpacing.md),
          KButton(
            key: resendKey,
            label: l10n.verifyResend,
            variant: KButtonVariant.secondary,
            loading: submitting,
            onPressed: resend,
          ),
        ],
      ),
    );
  }
}
