import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/ids/install_id.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/referrals/application/referral_providers.dart';
import 'package:kabso_live/features/referrals/data/referral_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Opens [ReferralCodeSheet] (Settings › «كود الدعوة»).
Future<void> showReferralCodeSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ReferralCodeSheet(),
    );

/// v1.74-social (D217, CONVENTIONS §10.71): a friend's invite code entered
/// after sign-up — once, within the days the server allows
/// (`MyReferral.canApply`, `applyUntil`). When the caller already has an
/// inviter, the days are over, or the programme is off, the sheet says so
/// instead of the form.
class ReferralCodeSheet extends ConsumerStatefulWidget {
  const new({super.key});

  static const fieldKey = Key('referral.apply.field');
  static const submitKey = Key('referral.apply.submit');
  static const closedKey = Key('referral.apply.closed');

  @override
  ConsumerState<ReferralCodeSheet> createState() => _ReferralCodeSheetState();
}

class _ReferralCodeSheetState extends ConsumerState<ReferralCodeSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(referralRepositoryProvider)
          .apply(_code.text, installId: ref.read(installIdProvider));
      if (!mounted) return;
      ref.invalidate(myReferralProvider);
      Navigator.of(context).pop();
      if (r.invitedByStatus == ReferralStatus.rejected) {
        KSnack.info(context, l10n.referralAppliedNotEligible);
      } else {
        KSnack.success(context, l10n.referralApplied);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureMessage(l10n, toAppFailure(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final p = context.palette;
    final load = ref.watch(myReferralProvider);
    final r = load.value;
    final Widget content;
    if (load.isLoading && r == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (load.hasError && r == null) {
      content = Text(
        failureMessage(l10n, toAppFailure(load.error!)),
        style: text.body.copyWith(color: p.error),
      );
    } else if (r == null || !r.enabled || !r.canApply) {
      content = Text(
        r == null || !r.enabled
            ? l10n.errorReferralUnavailable
            : r.invitedByStatus != null
            ? l10n.referralApplied
            : l10n.errorReferralNotAllowed,
        key: ReferralCodeSheet.closedKey,
        style: text.body,
      );
    } else {
      final until = r.applyUntil;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (until != null)
            Text(
              l10n.referralApplyBody(
                KFormat.date(
                  until.toLocal(),
                  Localizations.localeOf(context).toLanguageTag(),
                ),
              ),
              style: text.body.copyWith(color: p.textSecondary),
            ),
          const SizedBox(height: KSpacing.md),
          KTextField(
            fieldKey: ReferralCodeSheet.fieldKey,
            controller: _code,
            label: l10n.referralApplyLabel,
            textDirection: TextDirection.ltr,
            maxLength: 200,
            enabled: !_busy,
            errorText: _error,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => unawaited(_submit()),
          ),
          const SizedBox(height: KSpacing.md),
          KButton(
            key: ReferralCodeSheet.submitKey,
            label: l10n.referralApplySubmit,
            loading: _busy,
            onPressed: () => unawaited(_submit()),
          ),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KSpacing.lg,
        0,
        KSpacing.lg,
        KSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.referralApplyTitle, style: text.title),
            const SizedBox(height: KSpacing.md),
            content,
          ],
        ),
      ),
    );
  }
}
