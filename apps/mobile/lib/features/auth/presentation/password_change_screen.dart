import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.72-social (D208, §10.67): what the «كلمة مرور جديدة» screen needs after a
/// sign-in answered 403 `PASSWORD_CHANGE_REQUIRED` — the credentials just
/// typed (the team's temporary password, kept in memory only).
@immutable
final class PendingPasswordChange {
  const new({required this.identifier, required this.password});

  final String identifier;
  final String password;
}

class PendingPasswordChangeController extends Notifier<PendingPasswordChange?> {
  @override
  PendingPasswordChange? build() => null;

  PendingPasswordChange? get value => state;

  set value(PendingPasswordChange? next) => state = next;
}

final NotifierProvider<PendingPasswordChangeController, PendingPasswordChange?>
pendingPasswordChangeProvider =
    NotifierProvider<PendingPasswordChangeController, PendingPasswordChange?>(
      PendingPasswordChangeController.new,
    );

/// Signs in with `newPassword` (the server sets it, ends the other sessions)
/// and stores the session like any sign-in.
typedef ChangePasswordAtSignIn = Future<User> Function({
  required String identifier,
  required String password,
  required String newPassword,
});

final changePasswordAtSignInProvider = Provider<ChangePasswordAtSignIn>((ref) {
  final remote = ref.watch(authRemoteDataSourceProvider);
  final tokens = ref.watch(tokenManagerProvider);
  final config = ref.watch(appConfigProvider);
  return ({
    required identifier,
    required password,
    required newPassword,
  }) async {
    final res = await remote.login(
      LoginRequestDto(
        identifier: identifier.trim(),
        password: password,
        device: DeviceInfoDto(
          platform: clientPlatform(),
          appVersion: config.appVersion,
        ),
      ),
      newPassword: newPassword,
    );
    await tokens.saveTokens(res.tokens);
    return res.user.toEntity();
  };
});

/// `/auth/password-change` (D208): the team asked for a new password — choose
/// one (8–128 characters, not the current one) to sign in.
class PasswordChangeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const newKey = Key('passwordChange.new');
  static const confirmKey = Key('passwordChange.confirm');
  static const submitKey = Key('passwordChange.submit');

  @override
  ConsumerState<PasswordChangeScreen> createState() =>
      _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends ConsumerState<PasswordChangeScreen> {
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(PendingPasswordChange pending) async {
    if (_busy) return;
    final l10n = context.l10n;
    final next = _new.text;
    setState(() {
      _newError = next.runes.length < 8
          ? l10n.passwordChangeTooShort
          : next == pending.password
          ? l10n.passwordChangeSame
          : null;
      _confirmError = _newError == null && _confirm.text != next
          ? l10n.passwordChangeMismatch
          : null;
    });
    if (_newError != null || _confirmError != null) return;
    setState(() => _busy = true);
    try {
      final user = await ref.read(changePasswordAtSignInProvider)(
        identifier: pending.identifier,
        password: pending.password,
        newPassword: next,
      );
      ref.read(pendingPasswordChangeProvider.notifier).value = null;
      ref.read(sessionControllerProvider.notifier).signedIn(user);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final failure = toAppFailure(e);
      if (failure.code == ErrorCode.validationFailed) {
        setState(() => _newError = l10n.passwordChangeSame);
        return;
      }
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final pending = ref.watch(pendingPasswordChangeProvider);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: KAppBar(title: Text(l10n.passwordChangeTitle)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.lg,
              KSpacing.xl,
              KSpacing.lg,
              KSpacing.lg,
            ),
            children: [
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      color: p.primary,
                      size: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.passwordChangeTitle,
                  textAlign: TextAlign.center,
                  style: t.title,
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                l10n.passwordChangeBody,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.lg),
              KTextField(
                label: l10n.passwordChangeNew,
                fieldKey: PasswordChangeScreen.newKey,
                controller: _new,
                obscure: true,
                showPasswordLabel: l10n.passwordShow,
                hidePasswordLabel: l10n.passwordHide,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                errorText: _newError,
              ),
              const SizedBox(height: KSpacing.md),
              KTextField(
                label: l10n.passwordChangeConfirm,
                fieldKey: PasswordChangeScreen.confirmKey,
                controller: _confirm,
                obscure: true,
                showPasswordLabel: l10n.passwordShow,
                hidePasswordLabel: l10n.passwordHide,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                errorText: _confirmError,
              ),
              const SizedBox(height: KSpacing.xl),
              KButton(
                key: PasswordChangeScreen.submitKey,
                label: l10n.passwordChangeSubmit,
                loading: _busy,
                onPressed: pending == null ? null : () => _submit(pending),
              ),
              if (pending == null) ...[
                const SizedBox(height: KSpacing.sm),
                KButton(
                  label: l10n.loginTitle,
                  variant: KButtonVariant.ghost,
                  onPressed: () =>
                      GoRouter.maybeOf(context)?.go(AppRoutes.login),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
