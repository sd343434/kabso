import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/ambassadors/data/ambassador_repository.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_badge.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_programme_screen.dart';
import 'package:kabso_live/features/referrals/presentation/invite_friends_screen.dart'
    show inviteSharerProvider;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

String _n(int v) => KFormat.bidiIsolate(KFormat.grouped(v));

/// v1.140-social (D390, §10.179.6): the ambassador's dashboard — the code and
/// the link with copy and share, the badge and the level with its commission
/// and the progress to the next one, this month's targets, the referrals, the
/// commissions (in hold, held, paid, reversed) and the history.
class AmbassadorDashboardScreen extends ConsumerWidget {
  const new({super.key});

  static const copyKey = Key('ambassador.copy');
  static const shareKey = Key('ambassador.share');
  static const heldKey = Key('ambassador.payoutsHeld');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final dash = ref.watch(ambassadorDashboardProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.ambDashTitle),
        leading: Navigator.canPop(context) ? null : const SizedBox.shrink(),
      ),
      body: switch (dash) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(ambassadorDashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.xxl,
            ),
            children: [
              if (!value.enabled || value.payoutsHeld)
                _Notice(
                  key: heldKey,
                  text: value.enabled ? l10n.ambPayoutsHeld : l10n.ambOff,
                ),
              _LevelCard(d: value),
              const SizedBox(height: KSpacing.md),
              _CodeCard(d: value),
              const SizedBox(height: KSpacing.md),
              _MonthCard(d: value),
              const SizedBox(height: KSpacing.md),
              _StatsCard(
                title: l10n.ambReferrals,
                icon: Icons.group_rounded,
                cells: [
                  (l10n.ambTotal, value.referralsTotal),
                  (l10n.ambActive, value.referralsActive),
                  (l10n.ambPendingRefs, value.referralsPending),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              _StatsCard(
                title: l10n.ambCommissions,
                icon: Icons.savings_rounded,
                cells: [
                  (l10n.ambPending, value.pendingCherries),
                  (l10n.ambHeld, value.heldCherries),
                  (l10n.ambPaid, value.paidCherries),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              _History(d: value),
            ],
          ),
        ),
        AsyncError(:final error) => Center(
          child: Text(failureMessage(l10n, toAppFailure(error))),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

BoxDecoration _card(KPalette p) => BoxDecoration(
  color: p.surface,
  borderRadius: BorderRadius.circular(KRadius.lg),
  border: Border.all(color: p.border),
);

class _Notice extends StatelessWidget {
  const new({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.md),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.pause_circle_rounded, color: p.warning),
          const SizedBox(width: KSpacing.xs),
          Expanded(child: Text(text, style: context.textStyles.caption)),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const new({required this.d});

  final AmbassadorDashboard d;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final c = ambassadorLevelColors(d.levelCode, p);
    final next = d.nextLevel;
    final target = d.target;
    double frac(int have, int need) =>
        need <= 0 ? 1 : (have / need).clamp(0, 1);
    final progress = target == null
        ? 1.0
        : (frac(d.monthActiveReferrals, target.minActiveReferrals) +
                  frac(d.monthTopupCoins, target.minTopupCoins)) /
              2;
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.lg),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Color.lerp(c.from, p.surface, 0.55)!,
            Color.lerp(c.to, p.surface, 0.7)!,
          ],
        ),
        border: Border.all(color: c.to.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AmbassadorBadge(level: d.levelCode, large: true),
              const Spacer(),
              Icon(Icons.public_rounded, color: c.to, size: 28),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.ambCommissionRate(
              KFormat.bidiIsolate(ambassadorPercent(d.commissionBps)),
            ),
            style: t.bodyStrong,
          ),
          const SizedBox(height: KSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: c.to,
              backgroundColor: p.surface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          if (next == null)
            Text(l10n.ambTopLevel, style: t.caption)
          else ...[
            Text(
              l10n.ambNextLevel(l10n.ambLevelName(next.code)),
              style: t.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              [
                l10n.ambNeedActive(_n(next.activeReferrals)),
                l10n.ambNeedCoins(_n(next.topupCoins)),
              ].join(' · '),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeCard extends ConsumerWidget {
  const new({required this.d});

  final AmbassadorDashboard d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: _card(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.ambYourCode, style: t.bodyStrong),
          const SizedBox(height: KSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: p.background,
              borderRadius: BorderRadius.circular(KRadius.md),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                Text(
                  d.code,
                  textDirection: TextDirection.ltr,
                  style: t.headline.copyWith(
                    letterSpacing: 4,
                    color: p.primaryText,
                  ),
                ),
                Text(
                  d.link,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              Expanded(
                child: KButton(
                  key: AmbassadorDashboardScreen.copyKey,
                  label: l10n.ambCopy,
                  icon: Icons.copy_rounded,
                  variant: KButtonVariant.secondary,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: d.link));
                    if (context.mounted) {
                      KSnack.success(context, l10n.ambCopied);
                    }
                  },
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: KButton(
                  key: AmbassadorDashboardScreen.shareKey,
                  label: l10n.ambShare,
                  icon: Icons.share_rounded,
                  onPressed: () => unawaited(
                    ref
                        .read(inviteSharerProvider)
                        .share(l10n.ambShareText(d.code, d.link)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const new({required this.d});

  final AmbassadorDashboard d;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final target = d.target;
    Widget row(String label, int have, int? need) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: t.caption)),
              Text(
                need == null ? _n(have) : '${_n(have)} / ${_n(need)}',
                style: t.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (need != null && need > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (have / need).clamp(0, 1).toDouble(),
                minHeight: 6,
                color: p.primary,
                backgroundColor: p.border,
              ),
            ),
          ],
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: _card(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: p.primary, size: 20),
              const SizedBox(width: KSpacing.xs),
              Expanded(child: Text(l10n.ambThisMonth, style: t.bodyStrong)),
              Text(
                d.month,
                textDirection: TextDirection.ltr,
                style: t.caption.copyWith(color: p.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          row(
            l10n.ambActiveReferrals,
            d.monthActiveReferrals,
            target?.minActiveReferrals,
          ),
          row(
            l10n.ambQualifiedTopups,
            d.monthTopupCoins,
            target?.minTopupCoins,
          ),
          if (target != null) ...[
            const SizedBox(height: KSpacing.xs),
            Row(
              children: [
                AmbassadorBadge(level: target.code),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Text(
                    ambassadorRewardText(l10n, target.reward),
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const new({required this.title, required this.icon, required this.cells});

  final String title;
  final IconData icon;
  final List<(String, int)> cells;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: _card(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: p.primary, size: 20),
              const SizedBox(width: KSpacing.xs),
              Expanded(child: Text(title, style: t.bodyStrong)),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              for (final (i, (label, value)) in cells.indexed) ...[
                if (i > 0) const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                    decoration: BoxDecoration(
                      color: p.background,
                      borderRadius: BorderRadius.circular(KRadius.md),
                    ),
                    child: Column(
                      children: [
                        Text(
                          KFormat.grouped(value),
                          style: t.title.copyWith(color: p.textPrimary),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const new({required this.d});

  final AmbassadorDashboard d;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: _card(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.ambHistory, style: t.bodyStrong),
          if (d.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
              child: Text(
                l10n.ambNoHistory,
                style: t.caption.copyWith(color: p.textTertiary),
              ),
            ),
          for (final m in d.history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    m.month,
                    textDirection: TextDirection.ltr,
                    style: t.caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  AmbassadorBadge(level: m.levelAfter),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.ambRewardStatus(m.rewardStatus),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: KSpacing.sm),
          Text(l10n.ambRecent, style: t.bodyStrong),
          if (d.recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
              child: Text(
                l10n.ambNoHistory,
                style: t.caption.copyWith(color: p.textTertiary),
              ),
            ),
          for (final c in d.recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.friend, style: t.caption),
                        Text(
                          KFormat.date(c.at, locale),
                          style: t.caption.copyWith(color: p.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _n(c.cherries),
                        style: t.caption.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        l10n.ambCommissionStatus(c.status),
                        style: t.caption.copyWith(
                          color: switch (c.status) {
                            'CREDITED' => p.success,
                            'VOID' || 'REVERSED' => p.error,
                            _ => p.textSecondary,
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
