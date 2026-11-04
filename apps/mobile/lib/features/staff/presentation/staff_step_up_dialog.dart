import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.68-live (D273, §10.96.6): the step-up before the staff tools unlock —
/// the code of the authenticator the staff member uses for the admin panel.
/// The server checks it like the panel (single use; a wrong code counts
/// towards the same lockout). Not enrolled → the dialog says to set it up at
/// admin.kabsolive.com first. Returns true once unlocked.
Future<bool> showStaffStepUp(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const StaffStepUpDialog(),
    ) ??
    false;

class StaffStepUpDialog extends ConsumerStatefulWidget {
  const new({super.key, this.enrolled = true});

  static const codeKey = Key('staff.stepUp.code');
  static const confirmKey = Key('staff.stepUp.confirm');
  static const errorKey = Key('staff.stepUp.error');

  /// False shows the «set it up in the panel first» state straight away
  /// (the status said so).
  final bool enrolled;

  @override
  ConsumerState<StaffStepUpDialog> createState() => _StaffStepUpDialogState();
}

class _StaffStepUpDialogState extends ConsumerState<StaffStepUpDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;
  late bool _notEnrolled = !widget.enrolled;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(staffStatusProvider.notifier).stepUp(code);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _code.clear();
        if (failure.code == ErrorCode.staffTotpNotEnrolled) {
          _notEnrolled = true;
        } else {
          _error = failureMessage(context.l10n, failure);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    return AlertDialog(
      icon: const KabsoTeamShield(size: 44),
      title: Text(l10n.staffStepUpTitle, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_notEnrolled)
            Text(
              l10n.staffStepUpEnrol,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: p.textPrimary),
            )
          else ...[
            Text(
              l10n.staffStepUpBody,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.lg),
            TextField(
              key: StaffStepUpDialog.codeKey,
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              style: text.headline.copyWith(letterSpacing: 8),
              decoration: InputDecoration(
                labelText: l10n.staffStepUpCode,
                counterText: '',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onChanged: (v) {
                if (v.length == 6) unawaited(_submit());
              },
              onSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.staffStepUpLockedHint,
              key: _error == null ? null : StaffStepUpDialog.errorKey,
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: p.textTertiary),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        if (!_notEnrolled)
          FilledButton(
            key: StaffStepUpDialog.confirmKey,
            onPressed: _busy ? null : () => unawaited(_submit()),
            child: Text(l10n.staffStepUpConfirm),
          ),
      ],
    );
  }
}
