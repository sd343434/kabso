import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/settings/account_deletion/account_deletion_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/auth/deletion-pending` (v1.62-social, D193, §10.56): shown when signing
/// in to an account in its deletion grace period (409
/// `ACCOUNT_DELETION_PENDING`): «طلب حذف قيد التنفيذ — إلغاء الحذف؟».
/// Cancelling
/// signs in with `cancelDeletion: true` (the credentials just typed, held in
/// memory only) and the account is back as it was; keeping it goes back to
/// login.
class DeletionPendingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const cancelKey = Key('deletionPending.cancel');
  static const keepKey = Key('deletionPending.keep');

  @override
  ConsumerState<DeletionPendingScreen> createState() =>
      _DeletionPendingScreenState();
}

class _DeletionPendingScreenState extends ConsumerState<DeletionPendingScreen> {
  bool _busy = false;

  Future<void> _cancelDeletion(PendingDeletionSignIn pending) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final user = await ref
          .read(accountDeletionRepositoryProvider)
          .cancelAndSignIn(
            identifier: pending.identifier,
            password: pending.password,
          );
      ref.read(pendingDeletionSignInProvider.notifier).value = null;
      ref.read(sessionControllerProvider.notifier).signedIn(user);
      // Shown on the home screen (the root messenger survives the redirect).
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.deletionPendingRestored)));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  void _keep() {
    ref.read(pendingDeletionSignInProvider.notifier).value = null;
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    } else {
      router?.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final pending = ref.watch(pendingDeletionSignInProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = pending?.purgeAfter;
    final body = date == null
        ? l10n.deletionPendingBodyNoDate
        : l10n.deletionPendingBody(KFormat.date(date.toLocal(), locale));

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: KAppBar(title: Text(l10n.deletionPendingTitle)),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
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
                            color: p.error.withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.hourglass_top_rounded,
                            color: p.error,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: KSpacing.lg),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.deletionPendingTitle,
                        textAlign: TextAlign.center,
                        style: t.title,
                      ),
                    ),
                    const SizedBox(height: KSpacing.xs),
                    Text(
                      l10n.deletionPendingQuestion,
                      textAlign: TextAlign.center,
                      style: t.bodyStrong.copyWith(color: p.error),
                    ),
                    const SizedBox(height: KSpacing.md),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: t.body.copyWith(color: p.textSecondary),
                    ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KButton(
                      key: DeletionPendingScreen.cancelKey,
                      label: l10n.deletionPendingCancel,
                      loading: _busy,
                      onPressed: pending == null
                          ? null
                          : () => _cancelDeletion(pending),
                    ),
                    const SizedBox(height: KSpacing.sm),
                    KButton(
                      key: DeletionPendingScreen.keepKey,
                      label: l10n.deletionPendingKeep,
                      variant: KButtonVariant.ghost,
                      onPressed: _busy ? null : _keep,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
