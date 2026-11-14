import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/kyc/application/kyc_providers.dart';
import 'package:kabso_live/features/kyc/data/kyc_models.dart';
import 'package:kabso_live/features/kyc/data/kyc_repository.dart';
import 'package:kabso_live/features/kyc/presentation/kyc_flow.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// «تأكيد الهوية» (v1.80-kyc, D227, CONVENTIONS §10.77): the step the
/// host-apply, agency-open and recharge-apply forms show while Didit is on, in
/// place of the manual ID card + selfie. It says where the caller's check
/// stands — not started, in progress, approved, declined (with the reasons and
/// «إعادة المحاولة» when allowed), under review — and opens Didit's hosted
/// flow ([KycFlowLauncher]); afterwards it asks the server to read the result
/// (`syncKycCheck`) and refreshes.
class KycStep extends ConsumerStatefulWidget {
  const new({required this.purpose, super.key});

  final KycPurpose purpose;

  static const cardKey = Key('kyc.step');
  static const startKey = Key('kyc.start');
  static const statusKey = Key('kyc.status');
  static const errorKey = Key('kyc.error');

  @override
  ConsumerState<KycStep> createState() => _KycStepState();
}

class _KycStepState extends ConsumerState<KycStep> with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the browser (or from a notification): read the state again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(myKycProvider);
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode == 'ar'
        ? 'ar'
        : 'en';
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(kycRepositoryProvider);
    try {
      final session = await repo.start(widget.purpose, language: language);
      if (!mounted) return;
      final finished = await ref
          .read(kycFlowLauncherProvider)
          .open(context, session);
      // Whether the flow finished or was closed, read the result now (the
      // webhook may be late; a closed flow keeps its session for later).
      if (finished) {
        try {
          await repo.sync(session.check.id);
        } on Object {
          // The webhook brings it; the state below is refreshed anyway.
        }
      }
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      setState(() => _error = _refusal(l10n, failure));
    } finally {
      ref.invalidate(myKycProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  String _refusal(AppLocalizations l10n, AppFailure failure) {
    final issue = switch (failure) {
      ServerFailure(:final details) => details.firstOrNull?.issue,
      _ => null,
    };
    return switch (KycRefusal.fromWire(issue)) {
      KycRefusal.dailyLimit => l10n.kycRefusedDailyLimit,
      KycRefusal.inReview => l10n.kycStatusInReviewHint,
      KycRefusal.alreadyApproved => l10n.kycStatusApprovedHint,
      KycRefusal.accountNotActive => l10n.hostApplyNotActive,
      null =>
        failure.code == ErrorCode.kycUnavailable
            ? l10n.kycUnavailable
            : failureMessage(l10n, failure),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final kyc = ref.watch(myKycProvider);
    final state = kyc.value?.of(widget.purpose);
    final status = state?.status ?? KycStatus.notStarted;
    final (icon, color, title, hint) = switch (status) {
      KycStatus.approved => (
        Icons.verified_rounded,
        p.success,
        l10n.kycStatusApproved,
        l10n.kycStatusApprovedHint,
      ),
      KycStatus.inReview => (
        Icons.hourglass_top_rounded,
        p.warning,
        l10n.kycStatusInReview,
        l10n.kycStatusInReviewHint,
      ),
      KycStatus.inProgress => (
        Icons.timelapse_rounded,
        p.info,
        l10n.kycStatusInProgress,
        l10n.kycStatusInProgressHint,
      ),
      KycStatus.declined => (
        Icons.gpp_bad_rounded,
        p.error,
        l10n.kycStatusDeclined,
        l10n.kycStatusDeclinedHint,
      ),
      KycStatus.expired || KycStatus.abandoned => (
        Icons.history_rounded,
        p.textSecondary,
        l10n.kycStatusExpired,
        l10n.kycStatusExpiredHint,
      ),
      KycStatus.notStarted => (
        Icons.badge_rounded,
        p.primary,
        l10n.kycStatusNotStarted,
        l10n.kycStatusNotStartedHint,
      ),
    };
    final reasons = status == KycStatus.declined
        ? state?.check?.reasons ?? const <String>[]
        : const <String>[];
    final canStart = state?.canStart ?? false;
    final label = switch (status) {
      KycStatus.notStarted => l10n.kycStart,
      KycStatus.inProgress => l10n.kycContinue,
      _ => l10n.kycRetry,
    };
    final showButton =
        status != KycStatus.approved && status != KycStatus.inReview;
    final error = _error;
    return Container(
      key: KycStep.cardKey,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(KRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: KycStep.statusKey,
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                    const SizedBox(height: KSpacing.xxs),
                    Text(hint, style: t.body.copyWith(color: p.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: KSpacing.sm),
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: p.error),
                    const SizedBox(width: KSpacing.xs),
                    Expanded(
                      child: Text(
                        kycReasonText(l10n, r),
                        style: t.caption.copyWith(color: p.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (state?.refusal == KycRefusal.dailyLimit) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.kycRefusedDailyLimit,
              style: t.caption.copyWith(color: p.warning),
            ),
          ],
          if (showButton) ...[
            const SizedBox(height: KSpacing.sm),
            KButton(
              key: KycStep.startKey,
              label: label,
              icon: Icons.photo_camera_front_rounded,
              loading: _busy,
              onPressed: _busy || !canStart || kyc.isLoading
                  ? null
                  : () => unawaited(_start()),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.kycWhatHappens(KFormat.bidiIsolate('Didit')),
              style: t.caption.copyWith(color: p.textTertiary),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              error,
              key: KycStep.errorKey,
              style: t.caption.copyWith(color: p.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// A Didit / Kabso reason code in words (a general sentence for an unknown
/// one).
String kycReasonText(AppLocalizations l10n, String code) => switch (code) {
  'UNDER_MIN_AGE' => l10n.kycReasonUnderAge,
  'DATE_OF_BIRTH_MISSING' => l10n.kycReasonNoBirthDate,
  'DOCUMENT_EXPIRED' => l10n.kycReasonDocumentExpired,
  'NO_FACE_DETECTED' => l10n.kycReasonNoFace,
  'LOW_LIVENESS_SCORE' || 'LIVENESS_FACE_ATTACK' => l10n.kycReasonLiveness,
  'LOW_FACE_MATCH_SIMILARITY' => l10n.kycReasonFaceMatch,
  _ => l10n.kycReasonOther,
};

/// Whether a form may be sent with this purpose's check (D227): approved, or
/// — when [allowPending] — sent to Didit's review.
bool kycReady(MyKyc? kyc, KycPurpose purpose, {bool allowPending = true}) {
  if (kyc == null || !kyc.enabled) return true;
  final s = kyc.of(purpose);
  return s.approved || (allowPending && s.status == KycStatus.inReview);
}
