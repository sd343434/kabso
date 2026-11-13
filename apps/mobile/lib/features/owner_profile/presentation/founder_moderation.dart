import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/founder_moderation_repository.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart'
    show isKabsoOwnerProvider;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.99-social (D311, CONVENTIONS §10.117; owner: «يمكنه حذف او حظر او تحذير
/// اي شخص»): «إجراءات المؤسس» — on any profile's ⋯ menu and any person card,
/// for the app owner only: warn, ban for a time, ban for good, delete the
/// account. Owner decision: no authenticator code and no password, a
/// confirmation with the reason only (red for the destructive ones).

/// Who the founder acts on.
typedef FounderTarget = ({String id, String username, String name});

/// Whether «إجراءات المؤسس» is offered: the signed-in account is the app owner
/// and the person is someone else and not an owner (the server refuses both
/// anyway).
bool founderActionsOffered(
  WidgetRef ref, {
  required bool targetIsSelf,
  required bool targetIsOwner,
}) => !targetIsSelf && !targetIsOwner && ref.watch(isKabsoOwnerProvider);

abstract final class FounderActionKeys {
  /// The entry in a ⋯ menu.
  static const entry = Key('founder.actions.entry');
  static const sheet = Key('founder.actions.sheet');
  static Key action(FounderAction a) => Key('founder.actions.${a.wire}');
  static const dialog = Key('founder.action.dialog');
  static const reason = Key('founder.action.reason');
  static Key days(int days) => Key('founder.action.days.$days');
  static const confirm = Key('founder.action.confirm');
  static const cancel = Key('founder.action.cancel');
  static const error = Key('founder.action.error');
}

/// The ⋯ menu's entry «إجراءات المؤسس» (the caller shows it only when
/// [founderActionsOffered]).
class FounderActionsTile extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      key: FounderActionKeys.entry,
      leading: Icon(Icons.admin_panel_settings_outlined, color: p.warning),
      title: Text(context.l10n.founderActionsTitle),
      onTap: onTap,
    );
  }
}

String founderActionLabel(AppLocalizations l10n, FounderAction a) =>
    switch (a) {
      FounderAction.warn => l10n.founderActionWarn,
      FounderAction.suspend => l10n.founderActionSuspend,
      FounderAction.ban => l10n.founderActionBan,
      FounderAction.deleteAccount => l10n.founderActionDelete,
    };

String founderActionHint(AppLocalizations l10n, FounderAction a) => switch (a) {
  FounderAction.warn => l10n.founderActionWarnHint,
  FounderAction.suspend => l10n.founderActionSuspendHint,
  FounderAction.ban => l10n.founderActionBanHint,
  FounderAction.deleteAccount => l10n.founderActionDeleteHint,
};

IconData _iconOf(FounderAction a) => switch (a) {
  FounderAction.warn => Icons.warning_amber_rounded,
  FounderAction.suspend => Icons.timer_off_outlined,
  FounderAction.ban => Icons.block_rounded,
  FounderAction.deleteAccount => Icons.delete_forever_outlined,
};

/// The four actions as a sheet, then the chosen one's confirmation. True
/// when an action was done.
Future<bool> showFounderActions(
  BuildContext context,
  FounderTarget target,
) async {
  final action = await showModalBottomSheet<FounderAction>(
    context: context,
    showDragHandle: true,
    // Four actions with their lines, at large text too: it scrolls.
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FounderActionsSheet(target: target),
  );
  if (action == null || !context.mounted) return false;
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => FounderActionDialog(target: target, action: action),
  );
  return done ?? false;
}

/// The sheet of the four actions (public for the tests and the captures).
class FounderActionsSheet extends StatelessWidget {
  const new({required this.target, super.key});

  final FounderTarget target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return SafeArea(
      key: FounderActionKeys.sheet,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                KSpacing.lg,
                0,
                KSpacing.lg,
                KSpacing.sm,
              ),
              child: Text(
                l10n.founderActionsFor(KFormat.bidiIsolate(target.name)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
            ),
            for (final a in FounderAction.values)
              ListTile(
                key: FounderActionKeys.action(a),
                leading: Icon(
                  _iconOf(a),
                  color: a.destructive ? p.error : p.warning,
                ),
                title: Text(
                  founderActionLabel(l10n, a),
                  style: TextStyle(color: a.destructive ? p.error : null),
                ),
                subtitle: Text(
                  founderActionHint(l10n, a),
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
                onTap: () => Navigator.of(context).pop(a),
              ),
            const SizedBox(height: KSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// The confirmation of one action: what it does, the duration (a timed ban),
/// the required reason, and «تأكيد» (red for a ban or a deletion). The
/// request keeps one clientId, so a retry after a failure never acts twice.
/// Pops true once done (a success message is shown).
class FounderActionDialog extends ConsumerStatefulWidget {
  const new({required this.target, required this.action, super.key});

  final FounderTarget target;
  final FounderAction action;

  @override
  ConsumerState<FounderActionDialog> createState() => _FounderActionState();
}

class _FounderActionState extends ConsumerState<FounderActionDialog> {
  final _reason = TextEditingController();
  final String _clientId = newClientId();
  int _days = 7;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _ready => _reason.text.trim().isNotEmpty && !_busy;

  Future<void> _submit() async {
    if (!_ready) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(founderModerationRepositoryProvider)
          .act(
            userId: widget.target.id,
            action: widget.action,
            reason: _reason.text.trim(),
            clientId: _clientId,
            days: widget.action == FounderAction.suspend ? _days : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      KSnack.success(
        context,
        l10n.founderActionDone(founderActionLabel(l10n, widget.action)),
      );
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      setState(() {
        _busy = false;
        _error = switch (failure.code) {
          ErrorCode.adminActionRefused => _refusedMessage(l10n, failure),
          _ => failureMessage(l10n, failure),
        };
      });
    }
  }

  String _refusedMessage(AppLocalizations l10n, AppFailure failure) {
    final issues = failure is ServerFailure
        ? failure.details.map((d) => d.issue).toSet()
        : const <String>{};
    return issues.contains('self') || issues.contains('owner_target')
        ? l10n.founderActionSelfOrOwner
        : l10n.founderActionNotActive;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final a = widget.action;
    final label = founderActionLabel(l10n, a);
    return AlertDialog(
      key: FounderActionKeys.dialog,
      title: Text(
        l10n.founderActionConfirmTitle(
          label,
          KFormat.bidiIsolate(widget.target.name),
        ),
        style: t.title.copyWith(color: a.destructive ? p.error : null),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              founderActionHint(l10n, a),
              style: t.body.copyWith(color: p.textSecondary),
            ),
            if (a == FounderAction.suspend) ...[
              const SizedBox(height: KSpacing.md),
              Text(l10n.founderActionDuration, style: t.label),
              const SizedBox(height: KSpacing.xs),
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: [
                  for (final d in founderSuspendDays)
                    ChoiceChip(
                      key: FounderActionKeys.days(d),
                      label: Text(l10n.founderActionDays(d)),
                      selected: _days == d,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _days = d),
                    ),
                ],
              ),
            ],
            const SizedBox(height: KSpacing.md),
            Text(l10n.founderActionReason, style: t.label),
            const SizedBox(height: KSpacing.xs),
            TextField(
              key: FounderActionKeys.reason,
              controller: _reason,
              enabled: !_busy,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.founderActionReasonHint,
              ),
            ),
            if (_error case final message?) ...[
              const SizedBox(height: KSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  key: FounderActionKeys.error,
                  style: t.caption.copyWith(color: p.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: FounderActionKeys.cancel,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        KButton(
          key: FounderActionKeys.confirm,
          label: l10n.founderActionConfirm,
          expand: false,
          loading: _busy,
          variant: a.destructive
              ? KButtonVariant.destructive
              : KButtonVariant.primary,
          onPressed: _ready ? () => unawaited(_submit()) : null,
        ),
      ],
    );
  }
}
