import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.78-social (D223, CONVENTIONS §10.75): `DEVICE_ACCOUNT_LIMIT` on the
/// sign-up screens — «لا يمكن إنشاء أكثر من حسابين من نفس الجهاز. يمكنك تسجيل
/// الدخول إلى حساباتك الحالية.» with a «تسجيل الدخول» action (signing in is
/// never limited).
class DeviceLimitNotice extends StatelessWidget {
  const new({required this.failure, required this.onLogIn, super.key});

  static const messageKey = Key('deviceLimit.message');
  static const logInKey = Key('deviceLimit.logIn');

  final AppFailure failure;
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KInlineMessage(key: messageKey, message: failureMessage(l10n, failure)),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: logInKey,
          label: l10n.registerSignIn,
          variant: KButtonVariant.secondary,
          onPressed: onLogIn,
        ),
      ],
    );
  }
}
