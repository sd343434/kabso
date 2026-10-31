import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/settings/account_deletion/account_deletion_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/settings/delete-account` (v1.62-social, D193, CONVENTIONS §10.56): the
/// in-app account deletion «حذف الحساب» that Apple 5.1.1(v) and Google Play
/// require. Three steps: (1) what is deleted, lost and kept, the 30-day grace
/// period and what must be settled first; (2) the password again; (3) the
/// confirmation word. Then the server schedules the deletion, revokes every
/// session, and the app signs out locally (login explains how to cancel).
class AccountDeletionScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initialStep = 0});

  /// Captures and tests may open a later step directly.
  final int initialStep;

  static const continueKey = Key('deleteAccount.continue');
  static const passwordKey = Key('deleteAccount.password');
  static const confirmKey = Key('deleteAccount.confirm');
  static const submitKey = Key('deleteAccount.submit');
  static const blockersKey = Key('deleteAccount.blockers');
  static const stepKey = Key('deleteAccount.step');

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  static const _steps = 3;

  late int _step = widget.initialStep.clamp(0, _steps - 1);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _password.addListener(_changed);
    _confirm.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _wordMatches(String word) =>
      _confirm.text.trim().toUpperCase() == word.toUpperCase();

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _submit(String word) async {
    if (_submitting || !_wordMatches(word)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await ref
          .read(accountDeletionRepositoryProvider)
          .request(
            password: _password.text,
            confirmation: _confirm.text.trim(),
          );
      // The server already signed this device out; login says what happened.
      await ref.read(sessionControllerProvider.notifier).deletionRequested();
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      final l10n = context.l10n;
      setState(() {
        _submitting = false;
        if (failure.code == ErrorCode.reauthFailed) {
          _passwordError = l10n.errorReauthFailed;
          _step = 1;
        } else if (failure.code == ErrorCode.accountDeletionBlocked) {
          _step = 0;
          ref.invalidate(accountDeletionInfoProvider);
        } else {
          KSnack.error(context, failureMessage(l10n, failure));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final word = l10n.deleteAccountConfirmWord;
    final info = ref.watch(accountDeletionInfoProvider);
    final blocked = info.value?.blockers.isNotEmpty ?? true;

    final body = switch (_step) {
      0 => _IntroStep(info: info),
      1 => _PasswordStep(controller: _password, errorText: _passwordError),
      _ => _ConfirmStep(controller: _confirm, word: word),
    };
    final action = switch (_step) {
      0 => KButton(
        key: AccountDeletionScreen.continueKey,
        label: l10n.actionContinue,
        onPressed: blocked ? null : () => setState(() => _step = 1),
      ),
      1 => KButton(
        key: AccountDeletionScreen.continueKey,
        label: l10n.actionContinue,
        onPressed: _password.text.isEmpty
            ? null
            : () => setState(() {
                _passwordError = null;
                _step = 2;
              }),
      ),
      _ => KButton(
        key: AccountDeletionScreen.submitKey,
        label: l10n.deleteAccountSubmit,
        variant: KButtonVariant.destructive,
        loading: _submitting,
        onPressed: _wordMatches(word) ? () => _submit(word) : null,
      ),
    };

    return PopScope(
      canPop: _step == 0 && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) _back();
      },
      child: Scaffold(
        appBar: KAppBar(title: Text(l10n.deleteAccountTitle)),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    KSpacing.lg,
                    KSpacing.md,
                    KSpacing.lg,
                    KSpacing.lg,
                  ),
                  children: [
                    _StepHeader(step: _step + 1, total: _steps),
                    const SizedBox(height: KSpacing.lg),
                    body,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  KSpacing.lg,
                  KSpacing.sm,
                  KSpacing.lg,
                  KSpacing.lg,
                ),
                child: action,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Step 1 of 3" with three segments.
class _StepHeader extends StatelessWidget {
  const new({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      key: AccountDeletionScreen.stepKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.deleteAccountStep(step, total),
          style: context.textStyles.caption.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: KSpacing.xs),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 1; i <= total; i++) ...[
                if (i > 1) const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? p.error : p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A round icon above a step's title.
class _StepIcon extends StatelessWidget {
  const new(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ExcludeSemantics(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: p.error.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: p.error, size: 28),
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: context.textStyles.title),
  );
}

/// One "what is deleted / lost / kept" card.
class _InfoCard extends StatelessWidget {
  const new({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsetsDirectional.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: p.textSecondary)),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong),
                const SizedBox(height: KSpacing.xxs),
                Text(body, style: t.body.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroStep extends ConsumerWidget {
  const new({required this.info});

  final AsyncValue<AccountDeletionInfo> info;

  static String blockerText(AppLocalizations l10n, DeletionBlocker b) =>
      switch (b) {
        DeletionBlocker.rechargeAgent => l10n.deleteAccountBlockerRechargeAgent,
        DeletionBlocker.hostAgency => l10n.deleteAccountBlockerHostAgency,
        DeletionBlocker.pendingWithdrawal =>
          l10n.deleteAccountBlockerPendingWithdrawal,
        DeletionBlocker.pendingCherrySale =>
          l10n.deleteAccountBlockerPendingCherrySale,
        DeletionBlocker.negativeBalance =>
          l10n.deleteAccountBlockerNegativeBalance,
        DeletionBlocker.other => l10n.deleteAccountBlockerOther,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final data = info.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepIcon(Icons.delete_forever_rounded),
        const SizedBox(height: KSpacing.md),
        _StepTitle(l10n.deleteAccountIntroTitle),
        const SizedBox(height: KSpacing.lg),
        switch (info) {
          AsyncValue(:final value?) when value.blockers.isNotEmpty => Container(
            key: AccountDeletionScreen.blockersKey,
            padding: const EdgeInsetsDirectional.all(KSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.md),
              border: Border.all(color: p.error),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deleteAccountBlockedTitle,
                  style: t.bodyStrong.copyWith(color: p.error),
                ),
                for (final b in value.blockers) ...[
                  const SizedBox(height: KSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 4),
                        child: ExcludeSemantics(
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: p.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xs),
                      Expanded(
                        child: Text(blockerText(l10n, b), style: t.body),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          AsyncValue(:final error?, isLoading: false) => KErrorState(
            compact: true,
            title: l10n.errorUnknown,
            message: failureMessage(l10n, toAppFailure(error)),
            retryLabel: l10n.actionRetry,
            onRetry: () => ref.invalidate(accountDeletionInfoProvider),
          ),
          AsyncValue(hasValue: false) => const KSkeleton(
            height: 48,
            radius: KRadius.md,
          ),
          _ => const SizedBox.shrink(),
        },
        const SizedBox(height: KSpacing.md),
        _InfoCard(
          icon: Icons.person_off_outlined,
          title: l10n.deleteAccountWhatGoes,
          body: l10n.deleteAccountWhatGoesBody,
        ),
        const SizedBox(height: KSpacing.sm),
        _InfoCard(
          icon: Icons.toll_outlined,
          title: l10n.deleteAccountForfeit,
          body: l10n.deleteAccountForfeitBody,
        ),
        const SizedBox(height: KSpacing.sm),
        _InfoCard(
          icon: Icons.receipt_long_outlined,
          title: l10n.deleteAccountKept,
          body: l10n.deleteAccountKeptBody,
        ),
        const SizedBox(height: KSpacing.md),
        Container(
          padding: const EdgeInsetsDirectional.all(KSpacing.md),
          decoration: BoxDecoration(
            color: p.error.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(KRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.schedule_rounded, color: p.error),
              ),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Text(
                  l10n.deleteAccountGrace(data?.graceDays ?? 30),
                  style: t.body,
                ),
              ),
            ],
          ),
        ),
        if (data != null) ...[
          const SizedBox(height: KSpacing.md),
          Text(
            // U+2068/U+2069 keep the Latin address whole in an Arabic line.
            l10n.deleteAccountContact('\u2068${data.supportEmail}\u2069'),
            style: t.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _PasswordStep extends StatelessWidget {
  const new({required this.controller, required this.errorText});

  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepIcon(Icons.lock_outline_rounded),
        const SizedBox(height: KSpacing.md),
        _StepTitle(l10n.deleteAccountPasswordTitle),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.deleteAccountPasswordBody,
          style: context.textStyles.body.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: KSpacing.lg),
        KTextField(
          label: l10n.loginPasswordLabel,
          fieldKey: AccountDeletionScreen.passwordKey,
          controller: controller,
          obscure: true,
          showPasswordLabel: l10n.passwordShow,
          hidePasswordLabel: l10n.passwordHide,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          errorText: errorText,
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const new({required this.controller, required this.word});

  final TextEditingController controller;
  final String word;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typed = controller.text.trim();
    final mismatch =
        typed.isNotEmpty && typed.toUpperCase() != word.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepIcon(Icons.warning_amber_rounded),
        const SizedBox(height: KSpacing.md),
        _StepTitle(l10n.deleteAccountConfirmTitle),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.deleteAccountConfirmBody(word),
          style: context.textStyles.body.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: KSpacing.lg),
        KTextField(
          label: l10n.deleteAccountConfirmLabel,
          fieldKey: AccountDeletionScreen.confirmKey,
          controller: controller,
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
          errorText: mismatch ? l10n.deleteAccountConfirmMismatch : null,
        ),
      ],
    );
  }
}
