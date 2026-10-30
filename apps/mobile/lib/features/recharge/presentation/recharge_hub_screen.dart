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
import 'package:kabso_live/features/profile/domain/profile_models.dart';
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
  static const cherryTodayKey = Key('recharge.cherryToday');

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
    Widget linkRows({required bool inGroup}) => RechargeNavGroup(
      children: [
        RechargeNavRow(
          key: directoryKey,
          inGroup: inGroup,
          icon: Icons.storefront_rounded,
          title: l10n.rechargeDirectoryTitle,
          subtitle: l10n.rechargeDirectoryHint,
          onTap: () => context.push(AppRoutes.rechargeAgents),
        ),
        RechargeNavRow(
          key: cherriesKey,
          inGroup: inGroup,
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
      ],
    );
    final links = [MeSectionTitle(l10n.rechargeMore), linkRows(inGroup: true)];
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
        MeSectionTitle(l10n.rechargeManage),
        RechargeNavGroup(
          children: [
            RechargeNavRow(
              key: availabilityKey,
              inGroup: true,
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
              inGroup: true,
              icon: Icons.badge_rounded,
              title: l10n.rechargeEmployeesTitle,
              subtitle: l10n.rechargeEmployeesHint,
              onTap: () => context.push(AppRoutes.rechargeEmployees),
            ),
          ],
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

/// The agent's dashboard (owner polish): the header card (the frame with
/// the display name in its plate, the name, the code with copy and the
/// status), the stock as a balance card with «بيع عملات», the sales as
/// three tiles (count and coins) and today's cherry purchases from hosts.
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
    // The plate shows the display name (D185), never the code.
    final displayName = switch (user?.displayName.trim()) {
      final n? when n.isNotEmpty => n,
      _ => user?.username ?? '',
    };
    final statusColor = active ? p.success : p.error;
    return Column(
      key: RechargeHubScreen.dashboardKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RechargeCard(
          child: Column(
            children: [
              if (code != null && active)
                RechargeAgentFrame(
                  width: 150,
                  name: displayName,
                  code: code,
                  imageUrl: user?.avatarUrl,
                )
              else
                KAvatar(
                  name: displayName,
                  imageUrl: user?.avatarUrl,
                  size: KSizes.avatarLg,
                ),
              const SizedBox(height: KSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.title.copyWith(color: p.textPrimary),
                    ),
                  ),
                  if (code != null && active)
                    RechargeAgentBadge(
                      code: code,
                      height: inlineAgentBadgeHeight(t.title.fontSize!),
                    ),
                ],
              ),
              if (code != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        KFormat.bidiIsolate('@$code'),
                        textDirection: TextDirection.ltr,
                        style: t.bodyStrong.copyWith(color: p.primaryText),
                      ),
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
              RechargePill(
                label: active
                    ? l10n.rechargeStatusActive
                    : l10n.rechargeStatusSuspended,
                color: statusColor,
                dot: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.md),
        _BalanceCard(agent: agent, active: active),
        MeSectionTitle(l10n.rechargeSalesTitle),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, (key, label, totals)) in [
              (
                const Key('recharge.sales.today'),
                l10n.rechargeToday,
                agent.sales.today,
              ),
              (
                const Key('recharge.sales.7'),
                l10n.rechargeLast7,
                agent.sales.last7Days,
              ),
              (
                const Key('recharge.sales.30'),
                l10n.rechargeLast30,
                agent.sales.last30Days,
              ),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: KSpacing.sm),
              Expanded(
                child: _SalesTile(key: key, label: label, totals: totals),
              ),
            ],
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        RechargeNotice(
          key: RechargeHubScreen.cherryTodayKey,
          icon: Icons.local_florist_rounded,
          // Owner («حد وكيل مفتوح»): no «of …» when there is no cap (0).
          text: agent.dailyCherryCap > 0
              ? l10n.rechargeCherryToday(
                  KFormat.bidiIsolate(KFormat.grouped(agent.todayCherries)),
                  KFormat.bidiIsolate(KFormat.grouped(agent.dailyCherryCap)),
                )
              : l10n.rechargeCherryTodayNoCap(
                  KFormat.bidiIsolate(KFormat.grouped(agent.todayCherries)),
                ),
        ),
      ],
    );
  }
}

/// The stock as a balance: the Kabi coin, the amount, «مخزون العملات» and
/// «بيع عملات» (the page's primary action).
class _BalanceCard extends ConsumerWidget {
  const new({required this.agent, required this.active});

  final RechargeAgentDashboard agent;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.lg),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [KBrandColors.gold.withValues(alpha: 0.22), p.surfaceRaised],
        ),
        border: Border.all(color: KBrandColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            key: RechargeHubScreen.stockKey,
            label: l10n.rechargeStockLabel(KFormat.grouped(agent.stockCoins)),
            excludeSemantics: true,
            child: Row(
              children: [
                const KabsoArtIcon(KabsoArt.coin, size: 44),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.rechargeStock,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          KFormat.grouped(agent.stockCoins),
                          textDirection: TextDirection.ltr,
                          style: t.headline.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
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
    );
  }
}

/// One sales period: its name, the number of sales and the coins.
class _SalesTile extends StatelessWidget {
  const new({required this.label, required this.totals, super.key});

  final String label;
  final SalesTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final coins = KFormat.compact(totals.coins, l10n);
    return Semantics(
      container: true,
      label:
          '$label: ${l10n.rechargeSalesCount(totals.count)}, '
          '${l10n.rechargeStockLabel(KFormat.grouped(totals.coins))}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(KSpacing.sm),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(
              l10n.rechargeSalesCount(totals.count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xxs),
            Row(
              children: [
                const KabsoArtIcon(KabsoArt.coin, size: 14),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    // «1.2 مليون»: the app language's order.
                    coins,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

/// «بيع عملات»: the buyer (username or ID) with a live preview of who it
/// is, the coins (grouped as typed, quick amounts, the stock left), then a
/// confirmation that sums it up; one `Idempotency-Key` per sale (a retry
/// after a lost answer never sells twice). The buyer pays the agent outside
/// the app.
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
  static const previewKey = Key('recharge.sell.preview');
  static const remainingKey = Key('recharge.sell.remaining');
  static Key quickKey(int coins) => Key('recharge.sell.quick.$coins');

  /// The quick amounts (owner: 100K, 500K, 1M, 5M).
  static const quickAmounts = [100000, 500000, 1000000, 5000000];

  @override
  ConsumerState<RechargeSellSheet> createState() => _RechargeSellSheetState();
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _username = RegExp(r'^[a-z0-9._]{2,30}$');

class _RechargeSellSheetState extends ConsumerState<RechargeSellSheet> {
  final _buyer = TextEditingController();
  final _coins = TextEditingController();
  String _key = newIdempotencyKey();
  String? _lastBody;
  bool _busy = false;
  String? _error;
  Timer? _debounce;

  /// The username being looked up (after a short pause in typing).
  String? _lookup;

  @override
  void dispose() {
    _debounce?.cancel();
    _buyer.dispose();
    _coins.dispose();
    super.dispose();
  }

  int? get _amount => rechargeDigitsValue(_coins.text);

  String get _buyerText => _buyer.text.trim();

  /// The username to look up, or null (empty, an ID, or not a username).
  static String? _usernameOf(String raw) {
    final v = raw.trim().replaceFirst(RegExp('^@'), '').toLowerCase();
    return _username.hasMatch(v) ? v : null;
  }

  void _onBuyer(String _) {
    _debounce?.cancel();
    setState(() {
      _error = null;
      _lookup = null;
    });
    final name = _usernameOf(_buyer.text);
    if (name == null) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _lookup = name);
    });
  }

  Future<void> _submit(PublicProfile? found) async {
    final l10n = context.l10n;
    final coins = _amount;
    final buyer = _buyerText;
    final stock = widget.stock;
    if (buyer.isEmpty || coins == null || coins < 1) {
      setState(() => _error = l10n.rechargeSellInvalid);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => _SellConfirmDialog(
        buyer: buyer,
        found: found,
        coins: coins,
        stockAfter: stock == null ? null : stock - coins,
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
    final lookup = _lookup;
    final buyer = _buyerText;
    final isId = _uuid.hasMatch(buyer.replaceFirst(RegExp('^@'), ''));
    final pendingName = _usernameOf(buyer);
    final found = lookup == null
        ? null
        : ref.watch(rechargeBuyerProvider(lookup));
    // The buyer is valid when it is an ID (checked at the sale) or a
    // username that was found.
    final profile = switch (found) {
      AsyncValue(:final PublicProfile value) => value,
      _ => null,
    };
    final checking =
        pendingName != null &&
        (lookup != pendingName || (found?.isLoading ?? true));
    final notFound =
        !checking &&
        lookup != null &&
        found is AsyncData<PublicProfile?> &&
        found.value == null;
    final lookupFailed =
        !checking && lookup != null && found is AsyncError<PublicProfile?>;
    final buyerOk = isId || profile != null;
    final buyerError = buyer.isEmpty || checking || buyerOk
        ? null
        : notFound || pendingName == null
        ? l10n.rechargeBuyerNotFound
        : lookupFailed
        ? failureMessage(l10n, toAppFailure(found.error))
        : null;
    final coins = _amount;
    final overStock = stock != null && coins != null && coins > stock;
    final amountOk = coins != null && coins >= 1 && !overStock;
    final valid = buyerOk && amountOk && !_busy;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.lg,
            KSpacing.lg,
            KSpacing.lg,
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
              const SizedBox(height: KSpacing.md),
              KTextField(
                fieldKey: RechargeSellSheet.buyerKey,
                label: l10n.rechargeBuyer,
                helperText: l10n.rechargeBuyerHint,
                controller: _buyer,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                errorText: buyerError,
                onChanged: _onBuyer,
              ),
              if (checking)
                Padding(
                  padding: const EdgeInsets.only(top: KSpacing.xs),
                  child: Semantics(
                    label: l10n.rechargeBuyerChecking,
                    child: const LinearProgressIndicator(minHeight: 2),
                  ),
                )
              else if (profile != null) ...[
                const SizedBox(height: KSpacing.xs),
                _BuyerPreview(
                  key: RechargeSellSheet.previewKey,
                  profile: profile,
                ),
              ],
              const SizedBox(height: KSpacing.md),
              KTextField(
                fieldKey: RechargeSellSheet.coinsKey,
                label: l10n.rechargeCoins,
                controller: _coins,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                inputFormatters: const [RechargeGroupedDigitsFormatter()],
                errorText: overStock ? l10n.rechargeSellOverStock : _error,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: KSpacing.sm),
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: [
                  for (final q in RechargeSellSheet.quickAmounts)
                    KChip(
                      key: RechargeSellSheet.quickKey(q),
                      label: KFormat.compact(q, l10n),
                      selected: coins == q,
                      onSelected: stock != null && q > stock
                          ? null
                          : () => setState(() {
                              _coins.text = KFormat.grouped(q);
                              _error = null;
                            }),
                    ),
                ],
              ),
              if (stock != null) ...[
                const SizedBox(height: KSpacing.sm),
                Row(
                  key: RechargeSellSheet.remainingKey,
                  children: [
                    const KabsoArtIcon(KabsoArt.coin, size: 16),
                    const SizedBox(width: KSpacing.xs),
                    Expanded(
                      child: Text(
                        coins == null || coins < 1 || overStock
                            ? l10n.rechargeStockLeft(
                                KFormat.bidiIsolate(KFormat.grouped(stock)),
                              )
                            : l10n.rechargeStockAfter(
                                KFormat.bidiIsolate(
                                  KFormat.grouped(stock - coins),
                                ),
                              ),
                        style: t.caption.copyWith(
                          color: overStock ? p.error : p.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                onPressed: valid ? () => unawaited(_submit(profile)) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The buyer found: the photo, the display name and @username.
class _BuyerPreview extends StatelessWidget {
  const new({required this.profile, super.key});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: p.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: p.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          KAvatar(
            name: profile.displayName,
            imageUrl: profile.avatarUrl,
            size: KSizes.avatarSm + 8,
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                Text(
                  KFormat.bidiIsolate('@${profile.username}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: p.success, size: 20),
        ],
      ),
    );
  }
}

/// The sale summed up before it happens: the buyer, the coins and the
/// stock after it; «بيع عملات» or cancel.
class _SellConfirmDialog extends StatelessWidget {
  const new({
    required this.buyer,
    required this.found,
    required this.coins,
    required this.stockAfter,
  });

  final String buyer;
  final PublicProfile? found;
  final int coins;
  final int? stockAfter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final found = this.found;
    Widget line(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: t.body.copyWith(color: p.textSecondary)),
          ),
          const SizedBox(width: KSpacing.sm),
          Flexible(child: value),
        ],
      ),
    );
    return AlertDialog(
      title: Text(l10n.rechargeSellConfirmTitle),
      content: Column(
        key: const Key('recharge.sell.summary'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(
            l10n.rechargeBuyer,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (found != null) ...[
                  KAvatar(
                    name: found.displayName,
                    imageUrl: found.avatarUrl,
                    size: 24,
                  ),
                  const SizedBox(width: KSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    found == null
                        ? KFormat.bidiIsolate(buyer)
                        : found.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          line(
            l10n.rechargeCoins,
            Text(
              KFormat.grouped(coins),
              textDirection: TextDirection.ltr,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
          ),
          if (stockAfter case final after?)
            line(
              l10n.rechargeStockAfterLabel,
              Text(
                KFormat.grouped(after),
                textDirection: TextDirection.ltr,
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
            ),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.rechargeSellIrreversible,
            style: t.caption.copyWith(color: p.warning),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('recharge.sell.confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.rechargeSell),
        ),
      ],
    );
  }
}
