import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/recruits/data/recruits_repository.dart';
import 'package:kabso_live/features/wallet/presentation/cherry_withdraw_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The type's name in the app's language.
String recruitTypeName(AppLocalizations l10n, RecruitType t) => switch (t) {
  RecruitType.host => l10n.recruitTypeHost,
  RecruitType.agency => l10n.recruitTypeAgency,
  RecruitType.rechargeAgent => l10n.recruitTypeRechargeAgent,
  RecruitType.creator => l10n.recruitTypeCreator,
};

/// Basis points as a percentage: 100 → «1%», 75 → «0.75%».
String bpsPercent(int bps) {
  final v = bps / 100;
  if (v == v.roundToDouble()) return '${v.round()}%';
  var s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return '$s%';
}

/// US dollars with two decimals (Latin digits, like the wallet).
String usd(double v) => '\$${v.toStringAsFixed(2)}';

IconData _typeIcon(RecruitType t) => switch (t) {
  RecruitType.host => Icons.videocam_rounded,
  RecruitType.agency => Icons.groups_rounded,
  RecruitType.rechargeAgent => Icons.storefront_rounded,
  RecruitType.creator => Icons.auto_awesome_rounded,
};

Widget _failure(BuildContext context, Object error) => Center(
  child: Padding(
    padding: const EdgeInsets.all(KSpacing.xl),
    child: Text(
      failureMessage(context.l10n, toAppFailure(error)),
      textAlign: TextAlign.center,
    ),
  ),
);

/// v1.75-live (D285): «استقطاباتي» in the staff Me tab (MODERATION / BD) —
/// the people who joined through the staff member, by type with their status.
class StaffRecruitsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const listKey = Key('staffRecruits.list');
  static Key tabKey(RecruitType? t) => Key('staffRecruits.tab.${t?.wire}');

  @override
  ConsumerState<StaffRecruitsScreen> createState() =>
      _StaffRecruitsScreenState();
}

class _StaffRecruitsScreenState extends ConsumerState<StaffRecruitsScreen> {
  RecruitType? _type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final data = ref.watch(myStaffRecruitsProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.staffMyRecruits),
      ),
      body: switch (data) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(myStaffRecruitsProvider.future),
          child: ListView(
            key: StaffRecruitsScreen.listKey,
            padding: const EdgeInsets.all(KSpacing.lg),
            children: [
              Text(
                l10n.staffRecruitsIntro,
                style: t.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final type in <RecruitType?>[
                      null,
                      ...RecruitType.values,
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: KSpacing.xs,
                        ),
                        child: ChoiceChip(
                          key: StaffRecruitsScreen.tabKey(type),
                          selected: _type == type,
                          onSelected: (_) => setState(() => _type = type),
                          label: Text(_tabLabel(l10n, type, value)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.md),
              ..._rows(context, value),
            ],
          ),
        ),
        AsyncError(:final error) => _failure(context, error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static String _tabLabel(
    AppLocalizations l10n,
    RecruitType? type,
    StaffRecruitList list,
  ) {
    final name = type == null
        ? l10n.recruitTypeAll
        : recruitTypeName(l10n, type);
    final n = type == null ? list.total : list.counts[type] ?? 0;
    return '$name ($n)';
  }

  List<Widget> _rows(BuildContext context, StaffRecruitList list) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rows = [
      for (final r in list.recruits)
        if (_type == null || r.type == _type) r,
    ];
    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpacing.xxl),
          child: Text(
            l10n.staffRecruitsEmpty,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: p.textSecondary),
          ),
        ),
      ];
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    return [
      for (final r in rows)
        Card(
          key: Key('staffRecruits.row.${r.id}'),
          color: p.surface,
          margin: const EdgeInsets.only(bottom: KSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                KAvatar(
                  name: r.recruit.displayName,
                  imageUrl: r.recruit.avatarUrl,
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.recruit.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                      Text(
                        KHandle.plain(
                          r.recruit.username,
                          staffId: r.recruit.staffId,
                        ),
                        textDirection: TextDirection.ltr,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Wrap(
                        spacing: KSpacing.xs,
                        runSpacing: KSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Pill(
                            icon: _typeIcon(r.type),
                            text: recruitTypeName(l10n, r.type),
                            color: p.primary,
                          ),
                          _Pill(
                            text: r.active
                                ? l10n.recruitStatusActive
                                : l10n.recruitStatusInactive,
                            color: r.active ? p.success : p.textTertiary,
                          ),
                          Text(
                            l10n.recruitSince(
                              KFormat.date(r.activatedAt, locale),
                            ),
                            style: t.caption.copyWith(color: p.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Text(
                  l10n.recruitCherries(KFormat.grouped(r.commissionCherries)),
                  style: t.label.copyWith(color: p.textPrimary),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _Pill extends StatelessWidget {
  const new({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final i?) ...[
            Icon(i, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: t.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// v1.75-live (D285): «أرباحي» in the staff Me tab (MODERATION / BD) — the
/// commission balance (withdrawable cherries; the staff account's wallet is
/// hidden elsewhere, D283), the breakdown per recruit, the daily history and
/// «سحب الأرباح» through the existing withdrawal request.
class StaffEarningsScreen extends ConsumerWidget {
  const new({super.key});

  static const balanceKey = Key('staffEarnings.balance');
  static const withdrawKey = Key('staffEarnings.withdraw');
  static const historyKey = Key('staffEarnings.history');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final data = ref.watch(myStaffEarningsProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.staffMyEarnings),
      ),
      body: switch (data) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(myStaffEarningsProvider.future),
          child: _EarningsBody(earnings: value),
        ),
        AsyncError(:final error) => _failure(context, error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EarningsBody extends ConsumerWidget {
  const new({required this.earnings});

  final StaffEarnings earnings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final w = earnings.wallet;
    final money = (w.valueMinor / 100).toStringAsFixed(2);
    final canWithdraw =
        w.pendingWithdrawal == null &&
        w.withdrawableCherries > 0 &&
        w.valueMinor >= w.payout.minAmountMinor;
    Widget section(String title, List<Widget> children, {Key? key}) => Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: KSpacing.lg),
        Text(title, style: t.title.copyWith(color: p.textPrimary)),
        const SizedBox(height: KSpacing.sm),
        ...children,
      ],
    );
    return ListView(
      padding: const EdgeInsets.all(KSpacing.lg),
      children: [
        Container(
          key: StaffEarningsScreen.balanceKey,
          padding: const EdgeInsets.all(KSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE11D48), Color(0xFFF59E0B)],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(KRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.staffEarningsBalance,
                style: t.label.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: KSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.savings_rounded, color: Colors.white),
                  const SizedBox(width: KSpacing.sm),
                  Text(
                    KFormat.grouped(w.cherries),
                    style: t.display.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.staffEarningsWithdrawable(
                  KFormat.grouped(w.withdrawableCherries),
                  '\$$money',
                ),
                style: t.caption.copyWith(color: Colors.white),
              ),
              const SizedBox(height: KSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: l10n.staffEarningsTotal,
                      value: KFormat.grouped(earnings.totalCherries),
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: l10n.staffEarnings30,
                      value: KFormat.grouped(earnings.last30DaysCherries),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: StaffEarningsScreen.withdrawKey,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFE11D48),
                  ),
                  onPressed: canWithdraw
                      ? () async {
                          final done = await showCherryWithdrawSheet(
                            context,
                            w,
                          );
                          if (done != null) {
                            ref.invalidate(myStaffEarningsProvider);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.payments_rounded),
                  label: Text(
                    w.pendingWithdrawal != null
                        ? l10n.staffEarningsPending
                        : l10n.staffEarningsWithdraw,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        Text(
          l10n.staffEarningsShares(
            bpsPercent(earnings.bps[RecruitType.host] ?? 0),
            bpsPercent(earnings.bps[RecruitType.creator] ?? 0),
            bpsPercent(earnings.bps[RecruitType.agency] ?? 0),
            bpsPercent(earnings.bps[RecruitType.rechargeAgent] ?? 0),
          ),
          style: t.caption.copyWith(color: p.textSecondary),
        ),
        if (earnings.byRecruit.isEmpty && earnings.history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.xxl),
            child: Text(
              l10n.staffEarningsEmpty,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.textSecondary),
            ),
          ),
        if (earnings.byRecruit.isNotEmpty)
          section(l10n.staffEarningsByRecruit, [
            for (final r in earnings.byRecruit)
              _Line(
                user: r.recruit,
                subtitle: recruitTypeName(l10n, r.type),
                trailing: l10n.recruitCherries(KFormat.grouped(r.cherries)),
              ),
          ]),
        if (earnings.history.isNotEmpty)
          section(
            l10n.staffEarningsHistory,
            key: StaffEarningsScreen.historyKey,
            [
              for (final d in earnings.history)
                _Line(
                  user: d.recruit,
                  leading: d.day,
                  subtitle: l10n.staffEarningsDayLine(
                    usd(d.profitUsd),
                    bpsPercent(d.bps),
                  ),
                  trailing: '+${KFormat.grouped(d.cherries)}',
                ),
            ],
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.caption.copyWith(color: Colors.white70)),
        Text(value, style: t.bodyStrong.copyWith(color: Colors.white)),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const new({
    required this.user,
    required this.subtitle,
    required this.trailing,
    this.leading,
  });

  final UserSummary user;
  final String subtitle;
  final String trailing;
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
      child: Row(
        children: [
          KAvatar(name: user.displayName, imageUrl: user.avatarUrl),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [?leading, user.displayName].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                Text(
                  subtitle,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Text(trailing, style: t.label.copyWith(color: p.success)),
        ],
      ),
    );
  }
}
