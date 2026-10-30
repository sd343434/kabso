import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/application/agency_providers.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_cherry_tab.dart'
    show sharePercent;
import 'package:kabso_live/features/wallet/presentation/wallet_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/agency` «الوكالة» (D179, CONVENTIONS §10.46): host agencies.
///
/// - Not in an agency: join with the agent's invite code — the agency is
///   shown first, then «قبول والانضمام».
/// - A host: the agency, the leave window (14 days) and «مغادرة», after it
///   «شكوى إلى الإدارة» (the team resolves complaints).
/// - An agent: the invite code (copy), the rank and the progress to it
///   (active hosts x / 5, the hosts' month cherries vs the exception, the
///   sub-agencies for an agency admin), this month's rate, the commissions
///   and the hosts with their activity and month cherries.
///
/// D184: the same content is the Creator Center's «الوكالة» tab (D172), built
/// with [embedded] (no app bar of its own); the Me hub keeps the full page.
class AgencyScreen extends ConsumerWidget {
  const new({super.key, this.embedded = false});

  /// The body only (a pull-to-refresh list), for the Creator Center's tab.
  final bool embedded;

  static const codeFieldKey = Key('agency.code');
  static const findKey = Key('agency.find');
  static const acceptKey = Key('agency.accept');
  static const previewKey = Key('agency.preview');
  static const membershipKey = Key('agency.membership');
  static const leaveKey = Key('agency.leave');
  static const complainKey = Key('agency.complain');
  static const complaintKey = Key('agency.complaint');
  static const inviteKey = Key('agency.invite');
  static const copyKey = Key('agency.copy');
  static const rankKey = Key('agency.rank');
  static const progressKey = Key('agency.progress');
  static const commissionKey = Key('agency.commission');
  static const hostsEmptyKey = Key('agency.hosts.empty');

  static Key hostKey(String id) => Key('agency.host.$id');
  static Key subKey(String code) => Key('agency.sub.$code');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final load = ref.watch(myAgencyProvider);
    Future<void> refresh() async {
      ref
        ..invalidate(myAgencyProvider)
        ..invalidate(agencyHostsProvider);
      try {
        await ref.read(myAgencyProvider.future);
      } on Object {
        // The page shows the failure with a retry.
      }
    }

    final children = switch (load) {
      AsyncValue(:final value?) => [
        if (value.ownAgency case final own?)
          ..._agentSections(context, ref, value, own),
        if (value.membership case final m?)
          _MembershipCard(mine: value, membership: m),
        if (value.ownAgency == null && value.membership == null)
          _JoinCard(leaveDays: value.leaveDays),
      ],
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.agencyLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myAgencyProvider),
          compact: true,
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(KSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };
    if (embedded) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          key: const PageStorageKey('creator.agency'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xl,
          ),
          children: children,
        ),
      );
    }
    return MePage(
      title: l10n.agencyTitle,
      onRefresh: refresh,
      children: children,
    );
  }

  static List<Widget> _agentSections(
    BuildContext context,
    WidgetRef ref,
    MyAgency mine,
    OwnAgency own,
  ) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    String n(int v) => KFormat.grouped(v);
    final hosts = ref.watch(agencyHostsProvider);
    final notifier = ref.read(agencyHostsProvider.notifier);
    final hostRows = switch (hosts) {
      AsyncValue(value: FeedItems(:final items)) when items.isEmpty => [
        KEmptyState(
          key: hostsEmptyKey,
          icon: Icons.groups_rounded,
          title: l10n.agencyHostsEmpty,
          message: l10n.agencyHostsEmptyBody,
          compact: true,
        ),
      ],
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        [
          for (final h in items) _HostTile(host: h),
          if (hasMore)
            MeLoadMore(
              failed: loadMoreError != null,
              onLoad: notifier.loadMore,
              itemCount: items.length,
            ),
        ],
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.agencyLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(agencyHostsProvider),
          compact: true,
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(KSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };

    final showAdmin =
        own.rank == AgencyRank.admin ||
        own.subAgencies.isNotEmpty ||
        own.parentCommission.total > 0;
    return [
      // The invite code card.
      WalletBalanceCard(
        key: inviteKey,
        icon: Icon(Icons.qr_code_2_rounded, size: 30, color: p.primary),
        amount: WalletBigNumber(own.inviteCode),
        label: l10n.agencyInviteCode,
        semanticsLabel:
            '${l10n.agencyInviteCode}: ${own.inviteCode.split('').join(' ')}',
        tint: KBrandColors.red400,
        tintStrength: 0.18,
        action: WalletCardButton(
          key: copyKey,
          tooltip: l10n.agencyCopy,
          icon: Icons.copy_rounded,
          onPressed: () {
            unawaited(Clipboard.setData(ClipboardData(text: own.inviteCode)));
            KSnack.info(context, l10n.agencyCopied);
          },
        ),
        footer: Text(
          l10n.agencyInviteHint,
          style: t.caption.copyWith(color: p.textSecondary),
        ),
      ),
      const SizedBox(height: KSpacing.md),
      WalletSection(
        key: rankKey,
        title: l10n.agencyRankTitle,
        children: [
          Row(
            children: [
              _RankChip(rank: own.rank),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(
                  l10n.agencyRate(sharePercent(own.commissionRateBps)),
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.agencyRateNote(n(own.tierCherries)),
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          if (own.parent case final parent?) ...[
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.agencyParent(_name(parent.owner)),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ],
      ),
      const SizedBox(height: KSpacing.md),
      WalletSection(
        key: progressKey,
        title: l10n.agencyProgressTitle,
        children: [
          _Progress(
            label: l10n.agencyActiveHosts(
              own.activeHosts,
              own.requiredActiveHosts,
            ),
            value: own.activeHosts,
            target: own.requiredActiveHosts,
          ),
          Text(
            l10n.agencyActiveRule(
              mine.activeMinDays,
              mine.activeMinHours,
              mine.activeWindowDays,
            ),
            style: t.caption.copyWith(color: p.textTertiary),
          ),
          const SizedBox(height: KSpacing.md),
          _Progress(
            label: l10n.agencyMonthCherries(n(own.monthHostCherries)),
            value: own.monthHostCherries,
            target: own.exceptionCherries,
          ),
          Text(
            l10n.agencyException(
              n(own.exceptionCherries),
              own.requiredActiveHosts,
            ),
            style: t.caption.copyWith(color: p.textTertiary),
          ),
          if (showAdmin) ...[
            const SizedBox(height: KSpacing.md),
            _Progress(
              label: l10n.agencySubProgress(
                own.qualifiedSubAgencies,
                own.requiredSubAgencies,
              ),
              value: own.qualifiedSubAgencies,
              target: own.requiredSubAgencies,
            ),
          ],
          const SizedBox(height: KSpacing.md),
          Text(
            own.qualifiesNow
                ? l10n.agencyQualifiesNow
                : l10n.agencyNotQualifiedNow,
            style: t.label.copyWith(
              color: own.qualifiesNow ? p.success : p.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            l10n.agencyEvaluationNote,
            style: t.caption.copyWith(color: p.textTertiary),
          ),
        ],
      ),
      const SizedBox(height: KSpacing.md),
      WalletSection(
        key: commissionKey,
        title: l10n.agencyCommissionTitle,
        children: [
          _Totals(totals: own.commission),
          if (showAdmin) ...[
            const SizedBox(height: KSpacing.md),
            Text(
              l10n.agencyParentCommissionTitle,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xs),
            _Totals(totals: own.parentCommission),
          ],
        ],
      ),
      if (own.subAgencies.isNotEmpty) ...[
        const SizedBox(height: KSpacing.md),
        WalletSection(
          title: l10n.agencySubAgenciesTitle,
          children: [for (final s in own.subAgencies) _SubTile(sub: s)],
        ),
      ],
      const SizedBox(height: KSpacing.md),
      WalletSectionPiece(title: l10n.agencyHostsTitle(own.hostCount)),
      for (final row in hostRows) WalletSectionPiece(child: row),
      const WalletSectionPiece(bottom: true, child: SizedBox.shrink()),
    ];
  }
}

String _name(UserSummary u) =>
    KFormat.bidiIsolate(u.displayName.isEmpty ? u.username : u.displayName);

class _RankChip extends StatelessWidget {
  const new({required this.rank});

  final AgencyRank rank;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final (label, color) = switch (rank) {
      AgencyRank.newAgency => (l10n.agencyRankNew, p.info),
      AgencyRank.agent => (l10n.agencyRankAgent, p.success),
      AgencyRank.admin => (l10n.agencyRankAdmin, KBrandColors.red500),
      AgencyRank.lapsed => (l10n.agencyRankLapsed, p.textSecondary),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: KSpacing.xxs,
        ),
        child: Text(
          label,
          style: context.textStyles.label.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const new({required this.label, required this.value, required this.target});

  final String label;
  final int value;
  final int target;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = value >= target;
    final fraction = target <= 0 ? 1.0 : (value / target).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: label,
      value: '${(fraction * 100).floor()}%',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.textStyles.label.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
              if (done)
                Icon(Icons.check_circle_rounded, size: 18, color: p.success),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(KRadius.pill),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: p.border,
              color: done ? p.success : KBrandColors.red400,
            ),
          ),
          const SizedBox(height: KSpacing.xs),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const new({required this.totals});

  final CommissionTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MeStatGrid(
      stats: [
        (
          const Key('agency.commission.month'),
          l10n.agencyThisMonth,
          KFormat.grouped(totals.thisMonth),
        ),
        (
          const Key('agency.commission.last'),
          l10n.agencyLastMonth,
          KFormat.grouped(totals.lastMonth),
        ),
        (
          const Key('agency.commission.total'),
          l10n.agencyTotal,
          KFormat.grouped(totals.total),
        ),
      ],
    );
  }
}

class _SubTile extends StatelessWidget {
  const new({required this.sub});

  final SubAgency sub;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final line = l10n.agencySubLine(
      sub.activeHosts,
      KFormat.grouped(sub.monthHostCherries),
    );
    final status = sub.qualifies
        ? l10n.agencyQualified
        : l10n.agencyNotQualified;
    return Semantics(
      key: AgencyScreen.subKey(sub.inviteCode),
      container: true,
      label: '${_name(sub.owner)}, ${sub.inviteCode}, $line, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Row(
          children: [
            KAvatar(
              name: sub.owner.displayName,
              imageUrl: sub.owner.avatarUrl,
              size: 36,
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name(sub.owner),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(line, style: t.caption.copyWith(color: p.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Text(
              status,
              style: t.caption.copyWith(
                color: sub.qualifies ? p.success : p.textTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostTile extends StatelessWidget {
  const new({required this.host});

  final AgencyHostRow host;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final h = host;
    final line = l10n.agencyHostLine(
      h.liveDays,
      (h.liveSeconds / 3600).toStringAsFixed(1),
      KFormat.grouped(h.monthCherries),
    );
    final status = h.active ? l10n.agencyHostActive : l10n.agencyHostInactive;
    return Semantics(
      key: AgencyScreen.hostKey(h.user.id),
      container: true,
      label: [
        _name(h.user),
        status,
        line,
        if (!h.commissionEligible) l10n.agencyHostNoCommission,
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Row(
          children: [
            KAvatar(
              name: h.user.displayName,
              imageUrl: h.user.avatarUrl,
              size: 40,
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name(h.user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(line, style: t.caption.copyWith(color: p.textSecondary)),
                  if (!h.commissionEligible)
                    Text(
                      l10n.agencyHostNoCommission,
                      style: t.caption.copyWith(color: p.textTertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: (h.active ? p.success : p.textTertiary).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.sm,
                  vertical: KSpacing.xxs,
                ),
                child: Text(
                  status,
                  style: t.caption.copyWith(
                    color: h.active ? p.success : p.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Not in an agency: the code, the agency it opens, then «قبول والانضمام».
class _JoinCard extends ConsumerStatefulWidget {
  const new({required this.leaveDays});

  final int leaveDays;

  @override
  ConsumerState<_JoinCard> createState() => _JoinCardState();
}

class _JoinCardState extends ConsumerState<_JoinCard> {
  final _code = TextEditingController();
  AgencyPreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = await ref
          .read(agencyRepositoryProvider)
          .byCode(_code.text);
      if (mounted) setState(() => _preview = preview);
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (mounted) {
        setState(
          () => _error = failure.code == ErrorCode.notFound
              ? l10n.agencyNotFound
              : failureMessage(l10n, failure),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(AgencyPreview preview) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(agencyRepositoryProvider).join(preview.inviteCode);
      ref
        ..invalidate(myAgencyProvider)
        ..invalidate(agencyHostsProvider);
      if (mounted) KSnack.success(context, l10n.agencyJoined);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failureMessage(l10n, toAppFailure(e));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final preview = _preview;
    return WalletSection(
      title: l10n.agencyJoinTitle,
      children: [
        Text(
          l10n.agencyJoinBody,
          style: t.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: KSpacing.md),
        KTextField(
          fieldKey: AgencyScreen.codeFieldKey,
          label: l10n.agencyCodeLabel,
          controller: _code,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(12),
          ],
          onChanged: (_) => setState(() {
            _preview = null;
            _error = null;
          }),
          onSubmitted: (_) => unawaited(_find()),
        ),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: AgencyScreen.findKey,
          label: l10n.agencyFind,
          variant: KButtonVariant.secondary,
          loading: _busy && preview == null,
          onPressed: _code.text.trim().isEmpty || _busy
              ? null
              : () => unawaited(_find()),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: KSpacing.sm),
          Text(error, style: t.label.copyWith(color: p.error)),
        ],
        if (preview != null) ...[
          const SizedBox(height: KSpacing.md),
          _AgencyHeader(key: AgencyScreen.previewKey, agency: preview),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.agencyLeaveRule(widget.leaveDays),
            style: t.caption.copyWith(color: p.textTertiary),
          ),
          const SizedBox(height: KSpacing.md),
          KButton(
            key: AgencyScreen.acceptKey,
            label: l10n.agencyAccept,
            loading: _busy,
            onPressed: _busy ? null : () => unawaited(_accept(preview)),
          ),
        ],
      ],
    );
  }
}

class _AgencyHeader extends StatelessWidget {
  const new({required this.agency, super.key});

  final AgencyPreview agency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Semantics(
      container: true,
      label: [
        l10n.agencyPreviewOwner(_name(agency.owner)),
        agency.inviteCode,
        l10n.agencyHostCount(agency.hostCount),
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        children: [
          KAvatar(
            name: agency.owner.displayName,
            imageUrl: agency.owner.avatarUrl,
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.agencyPreviewOwner(_name(agency.owner)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                Text(
                  '${agency.inviteCode} · '
                  '${l10n.agencyHostCount(agency.hostCount)}',
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          _RankChip(rank: agency.rank),
        ],
      ),
    );
  }
}

/// The caller as a host: the agency, the leave window, leave or complain.
class _MembershipCard extends ConsumerStatefulWidget {
  const new({required this.mine, required this.membership});

  final MyAgency mine;
  final AgencyMembership membership;

  @override
  ConsumerState<_MembershipCard> createState() => _MembershipCardState();
}

class _MembershipCardState extends ConsumerState<_MembershipCard> {
  bool _busy = false;

  Future<void> _leave() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.agencyLeave),
        content: Text(l10n.agencyLeaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.agencyLeave),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(agencyRepositoryProvider).leave();
      ref.invalidate(myAgencyProvider);
      if (mounted) KSnack.success(context, l10n.agencyLeft);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      ref.invalidate(myAgencyProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complain() async {
    final l10n = context.l10n;
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ComplaintSheet(),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(agencyRepositoryProvider).complain(text);
      ref.invalidate(myAgencyProvider);
      if (mounted) KSnack.success(context, l10n.agencyComplaintSent);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final m = widget.membership;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final complaint = m.complaint;
    return WalletSection(
      key: AgencyScreen.membershipKey,
      title: l10n.agencyMyAgency,
      children: [
        _AgencyHeader(agency: m.agency),
        const SizedBox(height: KSpacing.md),
        Text(
          l10n.agencyJoinedAt(KFormat.date(m.joinedAt, localeTag)),
          style: t.label.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: KSpacing.xxs),
        Text(
          m.canLeave
              ? l10n.agencyLeaveUntil(KFormat.date(m.leaveUntil, localeTag))
              : l10n.agencyLeaveClosed(widget.mine.leaveDays),
          style: t.caption.copyWith(color: p.textTertiary),
        ),
        if (complaint != null) ...[
          const SizedBox(height: KSpacing.md),
          Text(
            complaint.open
                ? l10n.agencyComplaintOpen(
                    KFormat.date(complaint.createdAt, localeTag),
                  )
                : l10n.agencyComplaintDone,
            key: AgencyScreen.complaintKey,
            style: t.label.copyWith(
              color: complaint.open ? p.warning : p.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: KSpacing.lg),
        if (m.canLeave)
          KButton(
            key: AgencyScreen.leaveKey,
            label: l10n.agencyLeave,
            variant: KButtonVariant.secondary,
            loading: _busy,
            onPressed: _busy ? null : () => unawaited(_leave()),
          )
        else
          KButton(
            key: AgencyScreen.complainKey,
            label: l10n.agencyComplain,
            variant: KButtonVariant.secondary,
            icon: Icons.support_agent_rounded,
            loading: _busy,
            onPressed: _busy || (complaint?.open ?? false)
                ? null
                : () => unawaited(_complain()),
          ),
      ],
    );
  }
}

class _ComplaintSheet extends StatefulWidget {
  const new();

  @override
  State<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<_ComplaintSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.agencyComplain,
              textAlign: TextAlign.center,
              style: t.title.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: KSpacing.md),
            TextField(
              key: const Key('agency.complaint.text'),
              controller: _text,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: l10n.agencyComplaintHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KSpacing.md),
            KButton(
              key: const Key('agency.complaint.send'),
              label: l10n.agencyComplaintSend,
              onPressed: _text.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_text.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}
