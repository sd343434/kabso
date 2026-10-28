import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/features/premium/application/premium_providers.dart';
import 'package:kabso_live/features/premium/data/premium_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/settings/username` (D146): a new regular username. The rule (at least
/// 6 characters, letters and digits, a–z 0–9 and `_`) is checked as it is
/// typed, then availability; a premium-shaped name offers the store instead.
/// While a premium username is the person's, the change waits until it is
/// given back (the server says so too).
class ChangeUsernameScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const fieldKey = Key('changeUsername.field');
  static const saveKey = Key('changeUsername.save');
  static const premiumHintKey = Key('changeUsername.premiumHint');
  static const premiumActiveKey = Key('changeUsername.premiumActive');

  @override
  ConsumerState<ChangeUsernameScreen> createState() =>
      _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends ConsumerState<ChangeUsernameScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => AuthValidators.normalizeUsername(_controller.text);

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _value;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      final user = await ref
          .read(premiumRepositoryProvider)
          .changeUsername(name);
      ref.read(sessionControllerProvider.notifier).updateUser(user);
      ref.invalidate(meProvider);
      if (!mounted) return;
      KSnack.info(context, l10n.changeUsernameDone(user.username));
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      String message;
      if (failure is ServerFailure &&
          failure.code == ErrorCode.validationFailed) {
        final issue = failure.details
            .where((d) => d.field == 'username')
            .firstOrNull
            ?.issue;
        message =
            usernameIssueMessage(l10n, AuthValidators.issueFromWire(issue)) ??
            failureMessage(l10n, failure);
      } else if (failure is ServerFailure &&
          failure.code == ErrorCode.usernameTaken) {
        message = l10n.usernameTaken(name);
        ref.read(usernameAvailabilityProvider.notifier).markTaken(name);
      } else {
        message = failureMessage(l10n, failure);
      }
      setState(() => _serverError = message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final user = ref.watch(currentUserProvider);
    final premium = ref.watch(myPremiumProvider).value;
    final activePremium = premium != null && !premium.grace;
    final issue = _controller.text.isEmpty
        ? null
        : AuthValidators.usernameIssue(_value);
    final status = ref.watch(usernameAvailabilityProvider);
    final same = _value == user?.username;
    final canSave =
        !activePremium &&
        !_saving &&
        !same &&
        issue == null &&
        _controller.text.isNotEmpty &&
        status is! UsernameTaken &&
        status is! UsernameChecking;
    final Widget? statusLine = switch (status) {
      _ when issue != null || _controller.text.isEmpty || same => null,
      UsernameChecking() => Text(
        l10n.usernameChecking,
        style: text.caption.copyWith(color: p.textSecondary),
      ),
      UsernameAvailable(:final username) => Text(
        l10n.usernameAvailable(username),
        style: text.caption.copyWith(color: p.success),
      ),
      UsernameTaken(:final username) => Text(
        l10n.usernameTaken(username),
        style: text.caption.copyWith(color: p.error),
      ),
      UsernameUnknown() => Text(
        l10n.usernameCheckFailed,
        style: text.caption.copyWith(color: p.textSecondary),
      ),
      _ => null,
    };
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.changeUsernameTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          Text(
            l10n.changeUsernameCurrent,
            style: text.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: switch (user?.premiumTier) {
              final tier? => KSpecialUsername(
                username: user!.username,
                tier: tier,
              ),
              null => Text(
                KFormat.bidiIsolate('@${user?.username ?? ''}'),
                style: text.bodyStrong,
              ),
            },
          ),
          const SizedBox(height: KSpacing.lg),
          if (activePremium) ...[
            KInlineMessage(
              key: ChangeUsernameScreen.premiumActiveKey,
              isError: false,
              message: l10n.changeUsernamePremiumActive(
                premium.username,
                premium.regularUsername,
              ),
            ),
            const SizedBox(height: KSpacing.md),
            KButton(
              variant: KButtonVariant.secondary,
              label: l10n.premiumTitle,
              onPressed: () => context.push(AppRoutes.premium),
            ),
          ] else ...[
            KTextField(
              fieldKey: ChangeUsernameScreen.fieldKey,
              label: l10n.changeUsernameNew,
              controller: _controller,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.newUsername],
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                LengthLimitingTextInputFormatter(30),
              ],
              errorText:
                  _serverError ??
                  (issue == null || issue == UsernameIssue.required
                      ? null
                      : usernameIssueMessage(l10n, issue)),
              helperText: l10n.changeUsernameRule,
              status: statusLine,
              onChanged: (v) {
                setState(() => _serverError = null);
                ref.read(usernameAvailabilityProvider.notifier).onChanged(v);
              },
            ),
            if (issue == UsernameIssue.premium) ...[
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: ChangeUsernameScreen.premiumHintKey,
                variant: KButtonVariant.secondary,
                icon: Icons.workspace_premium_rounded,
                label: l10n.changeUsernameRentInstead(_value),
                onPressed: () => context.push(AppRoutes.premiumFor(_value)),
              ),
            ],
            const SizedBox(height: KSpacing.xl),
            KButton(
              key: ChangeUsernameScreen.saveKey,
              label: l10n.changeUsernameSave,
              loading: _saving,
              onPressed: canSave ? _save : null,
            ),
            const SizedBox(height: KSpacing.md),
            Text(
              l10n.changeUsernameNote,
              style: text.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
