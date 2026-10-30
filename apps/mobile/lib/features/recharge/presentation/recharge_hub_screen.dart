import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/recharge` «وكيل الشحن» (v1.54-social, D185, CONVENTIONS §10.48): what
/// the caller is in the recharge-agent programme.
///
/// - Nobody yet (or rejected): what an agent is and «كن وكيل شحن».
/// - Applied: «طلبك قيد المراجعة» (the data is private; nothing is shown).
/// - Approved: waiting for the first top-up of 30 000 000 coins.
/// - Active: the dashboard — the frame with the code, the stock, «بيع
///   عملات», today / 7 / 30 days, employees, the contact times, cherry
///   purchases from hosts. Suspended: the same, with selling off and the
///   reason to contact the team.
/// - An employee: the agent they work for, their hours and «بيع عملات»
///   while on shift.
///
/// Everyone also reaches the directory «وكلاء الشحن» and the cherry sales.
class RechargeHubScreen extends ConsumerWidget {
  const new({super.key});

  static const applyKey = Key('recharge.apply');
  static const pendingKey = Key('recharge.pending');
  static const approvedKey = Key('recharge.approved');
  static const suspendedKey = Key('recharge.suspended');
  static const dashboardKey = Key('recharge.dashboard');
  static const stockKey = Key('recharge.stock');
  static const sellKey = Key('recharge.sell');
  static const employeesKey = Key('recharge.employees');
  static const availabilityKey = Key('recharge.availability');
  static const cherriesKey = Key('recharge.cherries');
  static const directoryKey = Key('recharge.directory');
  static const employmentKey = Key('recharge.employment');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final load = ref.watch(myRechargeAgentProvider);
    Future<void> refresh() async {
      ref.invalidate(myRechargeAgentProvider);
      try {
        await ref.read(myRechargeAgentProvider.future);
      } on Object {
        // The page shows the failure with a retry.
      }
    }

    final children = switch (load) {
      AsyncValue(:final value?) => _sections(context, ref, value),
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myRechargeAgentProvider),
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
    return MePage(
      title: l10n.rechargeTitle,
      onRefresh: refresh,
      children: children,
    );
  }

  static List<Widget> _sections(
    BuildContext context,
    WidgetRef ref,
    RechargeAgentMe me,
  ) {
    final l10n = context.l10n;
    final agent = me.agent;
    final job = me.employment;
    final links = [
      const SizedBox(height: KSpacing.md),
      RechargeNavRow(
        key: directoryKey,
        icon: Icons.storefront_rounded,
        title: l10n.rechargeDirectoryTitle,
        subtitle: l10n.rechargeDirectoryHint,
        onTap: () => context.push(AppRoutes.rechargeAgents),
      ),
      RechargeNavRow(
        key: cherriesKey,
        icon: Icons.swap_horiz_rounded,
        title: agent?.status == RechargeAgentStatus.active
            ? l10n.rechargeCherryBuyTitle
            : l10n.rechargeCherrySellTitle,
        subtitle: l10n.rechargeCherryRate(
          KFormat.grouped(me.rules.cherryUnit),
          KFormat.grouped(me.rules.coinsPerCherryUnit),
        ),
        onTap: () => context.push(AppRoutes.rechargeCherries),
      ),
    ];
    if (agent != null) {
      return [
        if (agent.status == RechargeAgentStatus.approved)
          _StatusCard(
            key: approvedKey,
            icon: Icons.verified_rounded,
            title: l10n.rechargeApprovedTitle,
            body: l10n.rechargeApprovedBody(
              KFormat.bidiIsolate(KFormat.grouped(me.rules.activationMinCoins)),
            ),
          )
        else
          _Dashboard(me: me, agent: agent),
        if (agent.status == RechargeAgentStatus.suspended) ...[
          const SizedBox(height: KSpacing.md),
          _StatusCard(
            key: suspendedKey,
            icon: Icons.block_rounded,
            title: l10n.rechargeSuspendedTitle,
            body: l10n.rechargeSuspendedBody,
            warning: true,
          ),
        ],
        const SizedBox(height: KSpacing.md),
        MeSectionTitle(l10n.rechargeManage),
        RechargeNavRow(
          key: availabilityKey,
          icon: Icons.schedule_rounded,
          title: l10n.rechargeAvailabilityTitle,
          subtitle: agent.availability.slots.isEmpty
              ? l10n.rechargeAvailabilityEmpty
              : l10n.rechargeSlotCount(agent.availability.slots.length),
          onTap: () => unawaited(
            showRechargeAvailabilitySheet(context, ref, agent.availability),
          ),
        ),
        RechargeNavRow(
          key: employeesKey,
          icon: Icons.badge_rounded,
          title: l10n.rechargeEmployeesTitle,
          subtitle: l10n.rechargeEmployeesHint,
          onTap: () => context.push(AppRoutes.rechargeEmployees),
        ),
        ...links,
      ];
    }
    if (job != null) {
      return [_EmploymentCard(job: job), ...links];
    }
    return [
      switch (me.status) {
        RechargeAgentStatus.pending => _StatusCard(
          key: pendingKey,
          icon: Icons.hourglass_top_rounded,
          title: l10n.rechargePendingTitle,
          body: l10n.rechargePendingBody,
        ),
        _ => _Intro(me: me),
      },
      ...links,
    ];
  }
}

/// What an agent is, the privacy line and «كن وكيل شحن» (or, after a
/// rejection, the reason and «قدّم طلباً جديداً»).
class _Intro extends StatelessWidget {
  const new({required this.me});

  final RechargeAgentMe me;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rejected = me.status == RechargeAgentStatus.rejected;
    return RechargeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.asset(
              RechargeAgentArt.badge,
              height: 120,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.rechargeIntroTitle,
            textAlign: TextAlign.center,
            style: t.title.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.rechargeIntroBody,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.rechargeIntroActivation(
              KFormat.bidiIsolate(KFormat.grouped(me.rules.activationMinCoins)),
            ),
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          if (rejected) ...[
            const SizedBox(height: KSpacing.md),
            RechargeNotice(
              icon: Icons.info_outline_rounded,
              text: [
                l10n.rechargeRejectedTitle,
                if (me.rejectReason case final r? when r.isNotEmpty)
                  l10n.rechargeRejectedReason(r),
              ].join('\n'),
              warning: true,
            ),
          ],
          const SizedBox(height: KSpacing.lg),
          KButton(
            key: RechargeHubScreen.applyKey,
            label: rejected ? l10n.rechargeApplyAgain : l10n.rechargeBecome,
            icon: Icons.storefront_rounded,
            onPressed: me.canApply
                ? () => context.push(AppRoutes.rechargeApply)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return RechargeCard(
      child: Column(
        children: [
          Icon(icon, size: 40, color: warning ? p.error : p.primary),
          const SizedBox(height: KSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.title.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The agent's dashboard card: the frame with the code, the stock and «بيع
/// عملات», then the sales and today's cherry purchases.
class _Dashboard extends ConsumerWidget {
  const new({required this.me, required this.agent});

  final RechargeAgentMe me;
  final RechargeAgentDashboard agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final user = ref.watch(currentUserProvider);
    final code = agent.code;
    final active = agent.status == RechargeAgentStatus.active;
    String totals(SalesTotals s) => l10n.rechargeSalesTotals(
      s.count,
      KFormat.bidiIsolate(KFormat.grouped(s.coins)),
    );
    return Column(
      key: RechargeHubScreen.dashboardKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RechargeCard(
          child: Column(
            children: [
              if (code != null && active)
                RechargeAgentFrame(
                  width: 170,
                  name: user?.displayName ?? code,
                  code: code,
                  imageUrl: user?.avatarUrl,
                )
              else
                KAvatar(
                  name: user?.displayName ?? '',
                  imageUrl: user?.avatarUrl,
                  size: 88,
                ),
              const SizedBox(height: KSpacing.xs),
              if (code != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active) RechargeAgentBadge(code: code, height: 26),
                    const SizedBox(width: KSpacing.xs),
                    Text(
                      l10n.rechargeIdLine(KFormat.bidiIsolate(code)),
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                    IconButton(
                      tooltip: l10n.agencyCopy,
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: p.textSecondary,
                      ),
                      onPressed: () {
                        unawaited(Clipboard.setData(ClipboardData(text: code)));
                        KSnack.info(context, l10n.agencyCopied);
                      },
                    ),
                  ],
                ),
              const SizedBox(height: KSpacing.sm),
              Semantics(
                key: RechargeHubScreen.stockKey,
                label: l10n.rechargeStockLabel(
                  KFormat.grouped(agent.stockCoins),
                ),
                excludeSemantics: true,
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KabsoArtIcon(KabsoArt.coin, size: 30),
                        const SizedBox(width: KSpacing.xs),
                        Text(
                          KFormat.grouped(agent.stockCoins),
                          textDirection: TextDirection.ltr,
                          style: t.display.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      l10n.rechargeStock,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.md),
              KButton(
                key: RechargeHubScreen.sellKey,
                label: l10n.rechargeSell,
                icon: Icons.send_rounded,
                onPressed: active
                    ? () => unawaited(
                        showRechargeSellSheet(
                          context,
                          ref,
                          stock: agent.stockCoins,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.md),
        MeSectionTitle(l10n.rechargeSalesTitle),
        MeStatGrid(
          stats: [
            (
              const Key('recharge.sales.today'),
              l10n.rechargeToday,
              totals(agent.sales.today),
            ),
            (
              const Key('recharge.sales.7'),
              l10n.rechargeLast7,
              totals(agent.sales.last7Days),
            ),
            (
              const Key('recharge.sales.30'),
              l10n.rechargeLast30,
              totals(agent.sales.last30Days),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        RechargeNotice(
          icon: Icons.local_florist_rounded,
          text: l10n.rechargeCherryToday(
            KFormat.bidiIsolate(KFormat.grouped(agent.todayCherries)),
            KFormat.bidiIsolate(KFormat.grouped(agent.dailyCherryCap)),
          ),
        ),
      ],
    );
  }
}

/// An employee's card: the agent, the hours and «بيع عملات» while on shift.
class _EmploymentCard extends ConsumerWidget {
  const new({required this.job});

  final RechargeEmployment job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return RechargeCard(
      key: RechargeHubScreen.employmentKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KAvatar(
                name: job.agent.displayName,
                imageUrl: job.agent.avatarUrl,
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.rechargeEmployeeOf(
                        KFormat.bidiIsolate(job.agent.displayName),
                      ),
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                    if (job.agentCode case final code?)
                      Text(
                        l10n.rechargeIdLine(KFormat.bidiIsolate(code)),
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                  ],
                ),
              ),
              RechargeShiftChip(onShift: job.onShiftNow),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          for (final s in job.schedule)
            Text(
              rechargeSlotText(context, s, timeZone: job.timeZone),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          const SizedBox(height: KSpacing.md),
          KButton(
            key: RechargeHubScreen.sellKey,
            label: l10n.rechargeSell,
            icon: Icons.send_rounded,
            onPressed: job.onShiftNow
                ? () => unawaited(showRechargeSellSheet(context, ref))
                : null,
          ),
          if (!job.onShiftNow) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.errorRechargeOffShift,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// «بيع عملات»: the buyer (username or ID) and the coins, a confirmation,
/// one `Idempotency-Key` per sale (a retry after a lost answer never sells
/// twice). The buyer pays the agent outside the app.
Future<void> showRechargeSellSheet(
  BuildContext context,
  WidgetRef ref, {
  int? stock,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => RechargeSellSheet(stock: stock),
);

class RechargeSellSheet extends ConsumerStatefulWidget {
  const new({super.key, this.stock});

  /// The agent's stock (null for an employee, who does not see it).
  final int? stock;

  static const buyerKey = Key('recharge.sell.buyer');
  static const coinsKey = Key('recharge.sell.coins');
  static const submitKey = Key('recharge.sell.submit');

  @override
  ConsumerState<RechargeSellSheet> createState() => _RechargeSellSheetState();
}

class _RechargeSellSheetState extends ConsumerState<RechargeSellSheet> {
  final _buyer = TextEditingController();
  final _coins = TextEditingController();
  String _key = newIdempotencyKey();
  String? _lastBody;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _buyer.dispose();
    _coins.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_coins.text.trim());

  Future<void> _submit() async {
    final l10n = context.l10n;
    final coins = _amount;
    final buyer = _buyer.text.trim();
    if (buyer.isEmpty || coins == null || coins < 1) {
      setState(() => _error = l10n.rechargeSellInvalid);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(
          l10n.rechargeSellConfirm(
            KFormat.bidiIsolate(KFormat.grouped(coins)),
            KFormat.bidiIsolate(buyer),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('recharge.sell.confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.rechargeSell),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // A new sale gets a new key; the same one again (a retry) keeps it.
    final body = '$buyer|$coins';
    if (_lastBody != body) _key = newIdempotencyKey();
    _lastBody = body;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sale = await ref
          .read(rechargeRepositoryProvider)
          .sell(buyer: buyer, coins: coins, idempotencyKey: _key);
      if (!mounted) return;
      ref.invalidate(myRechargeAgentProvider);
      Navigator.of(context).pop();
      KSnack.success(
        context,
        l10n.rechargeSold(
          KFormat.bidiIsolate(KFormat.grouped(sale.coins)),
          KFormat.bidiIsolate(sale.buyer.displayName),
        ),
      );
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
    final p = context.palette;
    final t = context.textStyles;
    final stock = widget.stock;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.rechargeSellTitle,
              textAlign: TextAlign.center,
              style: t.title.copyWith(color: p.textPrimary),
            ),
            if (stock != null) ...[
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.rechargeStockLeft(
                  KFormat.bidiIsolate(KFormat.grouped(stock)),
                ),
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ],
            const SizedBox(height: KSpacing.md),
            KTextField(
              fieldKey: RechargeSellSheet.buyerKey,
              label: l10n.rechargeBuyer,
              helperText: l10n.rechargeBuyerHint,
              controller: _buyer,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KSpacing.sm),
            KTextField(
              fieldKey: RechargeSellSheet.coinsKey,
              label: l10n.rechargeCoins,
              controller: _coins,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              errorText: _error,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: KSpacing.sm),
            RechargeNotice(
              icon: Icons.info_outline_rounded,
              text: l10n.rechargeSellNote,
            ),
            const SizedBox(height: KSpacing.md),
            KButton(
              key: RechargeSellSheet.submitKey,
              label: l10n.rechargeSell,
              loading: _busy,
              onPressed: _busy ? null : () => unawaited(_submit()),
            ),
          ],
        ),
      ),
    );
  }
}
