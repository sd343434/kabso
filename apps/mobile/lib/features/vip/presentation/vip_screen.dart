import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_ref_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What the sticky button does for the tier on screen (the server decides
/// again; D252, CONVENTIONS §10.93.2).
enum VipAction {
  /// No active membership: the tier for its length from now.
  buy,

  /// The same tier: the end moves by its length.
  renew,

  /// A higher tier: from now, at its full price; the days left are not
  /// carried over.
  upgrade,

  /// A lower tier while a higher one is active: not sold until it ends.
  lower,

  /// A renewal would end more than `maxAheadDays` from now.
  renewLimit,
}

/// The action for [tier] given the caller's [membership] and the [list]
/// on sale (the held tier's place in it is its rank).
VipAction vipActionFor(
  VipTier tier,
  VipMembership? membership,
  VipTierList list,
  DateTime now,
) {
  if (membership == null || !membership.expiresAt.isAfter(now)) {
    return VipAction.buy;
  }
  if (membership.tierId == tier.id) {
    final end = membership.expiresAt.add(Duration(days: tier.durationDays));
    final limit = now.add(Duration(days: list.maxAheadDays));
    return end.isAfter(limit) ? VipAction.renewLimit : VipAction.renew;
  }
  final held = list.tiers.where((t) => t.id == membership.tierId).firstOrNull;
  // A held tier taken off sale has no place in the list: the server
  // compares the ranks.
  if (held == null) return VipAction.buy;
  return tier.level > held.level ? VipAction.upgrade : VipAction.lower;
}

/// `/vip` (D252, owner «اصنع صفحة شراء vip»; D252b v2 owner «طبق هذا التصميم
/// ١٠٠٪», reference `REFERENCE_vip_design_v2`): «شراء VIP» in the owner's new
/// reference layout — a centered «VIP» app bar, a horizontal tier tab row
/// (VIP1…VIPn, the selected one gold with an underline), the selected tier's
/// large centred BADGE, a gold crown divider, category section headers with a
/// count, a 3-column perks grid (thumbnail + title + subtitle), and a sticky
/// bar with the price/length and the activate button — in Kabso's dark purple +
/// gold identity, RTL-correct. The badge and perk thumbnails are slots for the
/// owner's own hosted art (admin panel); the crown divider is drawn in code
/// (the reference's third-party art is not copied). Tiers, prices and perks
/// come from the admin panel; buying is coins only (`POST /me/vip/purchases`).
class VipScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const statusKey = Key('vip.status');

  /// D258: «من زار ملفي» in the member's sheet.
  static const visitorsKey = Key('vip.visitors');
  static const emblemKey = Key('vip.emblem');
  static const ctaKey = Key('vip.cta');
  static const barKey = Key('vip.bar');
  static const emptyKey = Key('vip.empty');
  static const offSaleKey = Key('vip.offSale');
  static const confirmKey = Key('vip.confirm');
  static const payKey = Key('vip.confirm.pay');
  static const rechargeKey = Key('vip.confirm.recharge');
  static const cancelKey = Key('vip.confirm.cancel');
  static const shortKey = Key('vip.confirm.short');

  static Key tabKey(String code) => Key('vip.tab.$code');
  static Key perkKey(String code) => Key('vip.perk.$code');

  /// D258: the package's value line in the bottom bar.
  static const dailyTotalKey = Key('vip.dailyTotal');

  /// D258: the renewal discount line, and the list price struck through.
  static const renewalLineKey = Key('vip.renewalLine');
  static const listPriceKey = Key('vip.listPrice');

  /// D258: the page's tier-coloured background.
  static const backdropKey = Key('vip.backdrop');

  /// D258: the page's background for [tier] — a vertical gradient of deep
  /// shades of its colour (VIP 1 #2E8B3D → ≈ #0B230F / #050E06).
  static List<Color> backdropOf(VipTier? tier) {
    final c = Color(tier?.color ?? 0xFF2A2338);
    return [
      Color.lerp(c, const Color(0xFF000000), 0.75)!,
      Color.lerp(c, const Color(0xFF000000), 0.9)!,
    ];
  }

  @override
  ConsumerState<VipScreen> createState() => _VipScreenState();
}

enum _Decision { pay, recharge }

class _VipScreenState extends ConsumerState<VipScreen> {
  String? _selectedId;
  bool _busy = false;

  VipTier? _selected(VipTierList list, VipMembership? membership) {
    if (list.tiers.isEmpty) return null;
    final id = _selectedId ?? membership?.tierId;
    return list.tiers.where((t) => t.id == id).firstOrNull ?? list.tiers.first;
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(vipTiersProvider)
      ..invalidate(myVipProvider)
      ..invalidate(liveCoinsProvider);
    try {
      await Future.wait([
        ref.read(vipTiersProvider.future),
        ref.read(myVipProvider.future),
      ]);
    } on Object {
      // The page shows the failure with a retry.
    }
  }

  /// D258 (§10.94.12): what buying [tier] costs the caller now — the
  /// renewal price when the server quotes the caller's renewal discount for
  /// it, else the list price.
  int _priceOf(VipTier tier) {
    final renewal = ref.read(myVipRenewalProvider).value;
    return renewal != null && renewal.tierId == tier.id
        ? renewal.priceCoins
        : tier.priceCoins;
  }

  Future<void> _start(
    VipTier tier,
    VipAction action,
    VipMembership? membership,
  ) async {
    final balance = ref.read(liveCoinsProvider).value;
    final price = _priceOf(tier);
    final decision = await showKLiveDialog<_Decision>(
      context,
      builder: (dialog) => _ConfirmCard(
        tier: tier,
        action: action,
        membership: membership,
        balance: balance,
        chargeCoins: price,
      ),
    );
    if (!mounted) return;
    if (decision == _Decision.recharge) {
      unawaited(context.push(AppRoutes.wallet));
      return;
    }
    if (decision != _Decision.pay) return;
    await _buy(tier, price);
  }

  Future<void> _buy(VipTier tier, int price) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(vipRepositoryProvider)
          .buy(
            tierId: tier.id,
            priceCoins: price,
            idempotencyKey: newIdempotencyKey(),
          );
      ref.read(liveCoinsProvider.notifier).set(result.coins);
      ref
        ..invalidate(myVipProvider)
        ..invalidate(myVipRenewalProvider);
      if (!mounted) return;
      KSnack.info(
        context,
        l10n.vipDone(
          result.membership.tierName,
          KFormat.date(result.membership.expiresAt, l10n.localeName),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      var message = failureMessage(l10n, failure);
      if (failure is ServerFailure) {
        final code = failure.code;
        if (code == ErrorCode.vipPriceChanged) {
          ref.invalidate(vipTiersProvider);
        } else if (code == ErrorCode.insufficientCoins) {
          ref.invalidate(liveCoinsProvider);
          message = l10n.vipShort;
        } else if (code == ErrorCode.vipUnavailable) {
          ref
            ..invalidate(vipTiersProvider)
            ..invalidate(myVipProvider);
          final issue = failure.details
              .where((d) => d.field == 'tier')
              .firstOrNull
              ?.issue;
          message = switch (issue) {
            'downgrade' => l10n.vipErrorDowngrade,
            'renewal_limit' => l10n.vipErrorRenewLimit,
            'tier_off' => l10n.vipErrorTierOff,
            _ => message,
          };
        }
      }
      KSnack.error(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // D258 (owner, supersedes D252c's white / black): the page takes the
    // tier's colour — a deep tint of it in both modes, the art glowing on
    // it, the text white — so it is drawn with the dark palette.
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final l10n = context.l10n;
    final tiers = ref.watch(vipTiersProvider);
    final mine = ref.watch(myVipProvider);
    ref
      ..watch(liveCoinsProvider) // keeps the balance loaded for the bar.
      ..watch(myVipRenewalProvider); // D258: the renewal price.
    final list = tiers.value;
    final membership = mine.value;
    final ready = list != null && mine.hasValue;
    final tier = ready ? _selected(list, membership) : null;
    final now = clock.now();
    final failure = tiers.error ?? mine.error;

    final palette = VipPalette.of(context);
    final List<Widget> body;
    if (ready && tier != null && list.tiers.isNotEmpty) {
      // The caller holds this tier or a higher one now (so its perks are the
      // caller's): the buy button would renew it, not buy or upgrade.
      final action = vipActionFor(tier, membership, list, now);
      final held = action == VipAction.renew || action == VipAction.lower;
      body = [
        // «الخاص بي VIP ›» at the end edge (members only; their status).
        SizedBox(
          height: KVip.myChipHeight,
          child: membership == null
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: VipMyChip(
                    key: VipScreen.statusKey,
                    label: l10n.vipMine,
                    onTap: () => unawaited(_showMine(membership)),
                  ),
                ),
        ),
        // D258 (owner, reference 38): the badge on its stage with the tier's
        // glow, then «التعريف» and a live preview of every perk.
        Stack(
          alignment: Alignment.center,
          children: [
            VipStage(key: VipScreen.emblemKey, tier: tier),
            if (tier.badgeStill == null && tier.badgeAnimation == null)
              Positioned(bottom: 18, child: VipNamePlate(name: tier.name)),
          ],
        ),
        VipIdentityPanel(tier: tier, active: held),
      ];
    } else if (ready) {
      body = [
        const SizedBox(height: KSpacing.xxl),
        Column(
          key: VipScreen.emptyKey,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 56,
              color: palette.muted,
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.vipEmpty,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(color: palette.muted),
            ),
          ],
        ),
      ];
    } else if (failure != null && !tiers.isLoading && !mine.isLoading) {
      body = [
        const SizedBox(height: KSpacing.xxl),
        FailureErrorState(
          title: l10n.vipLoadError,
          failure: toAppFailure(failure),
          onRetry: () {
            ref
              ..invalidate(vipTiersProvider)
              ..invalidate(myVipProvider);
          },
          compact: true,
        ),
      ];
    } else {
      body = [
        const Padding(
          padding: EdgeInsets.all(KSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final showBar = ready && tier != null && list.tiers.isNotEmpty;
    final backdrop = VipScreen.backdropOf(tier);
    return Scaffold(
      backgroundColor: backdrop.last,
      body: AnimatedContainer(
        key: VipScreen.backdropKey,
        // A cross-fade as the tabs change (none with reduced motion).
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: backdrop,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // The tabs row: back at the start, the tiers (scrolling) after.
              SizedBox(
                height: KVip.tabRow + 6,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      // Mirrors in RTL (ref «›» at the right).
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: palette.text,
                        size: 28,
                      ),
                    ),
                    Expanded(
                      child: showBar
                          ? VipRefTabs(
                              tiers: list.tiers,
                              selectedId: tier.id,
                              onSelect: (t) =>
                                  setState(() => _selectedId = t.id),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: KSpacing.xl),
                    children: body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: !showBar
          ? null
          : _BottomBar(
              tier: tier,
              chargeCoins: _priceOf(tier),
              action: vipActionFor(tier, membership, list, now),
              busy: _busy,
              onPressed: (action) =>
                  unawaited(_start(tier, action, membership)),
            ),
    );
  }

  /// D258: whether the member's tier holds [code] (with inheritance).
  bool _holds(VipMembership m, String code) {
    final look = vipLookOf(
      UserVip(tier: m.tierCode, rank: 0, color: m.tierColor),
      ref.read(vipTiersProvider).value,
    );
    return look?.has(code) ?? false;
  }

  /// «الخاص بي VIP»: the member's own VIP — its tier, end and days left.
  Future<void> _showMine(VipMembership membership) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: VipPalette.of(context).sheet,
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MemberStatus(membership: membership),
                // D258: «من زار ملفي» (PROFILE_VISITORS).
                if (_holds(membership, VipPerks.profileVisitors)) ...[
                  const SizedBox(height: KSpacing.sm),
                  ListTile(
                    key: VipScreen.visitorsKey,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_outlined),
                    title: Text(context.l10n.vipVisitorsEntry),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(sheet).pop();
                      unawaited(context.push(AppRoutes.vipVisitors));
                    },
                  ),
                ],
                // D258: the daily coins (DAILY_COINS), claimed here.
                if (membership.dailyCoins case final daily?) ...[
                  const SizedBox(height: KSpacing.md),
                  VipDailyCoinsRow(initial: daily),
                ],
              ],
            ),
          ),
        ),
      );
}

/// A compact membership line for a member: the tier, the end date and the days
/// left, with an off-sale note when the owner took the tier off sale. (The
/// reference has no status line; this surfaces the member's own expiry only.)
class _MemberStatus extends StatelessWidget {
  const new({required this.membership});

  final VipMembership membership;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final m = membership;
    final until = l10n.vipUntil(
      m.tierName,
      KFormat.date(m.expiresAt, l10n.localeName),
    );
    return Column(
      key: VipScreen.statusKey,
      children: [
        Text(
          '$until · ${l10n.vipDaysLeft('${m.daysLeft}')}',
          textAlign: TextAlign.center,
          // ≥ 4.5:1 on the sheet in both themes (D258 readability pass).
          style: t.caption.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFB9A9C9)
                : const Color(0xFF5F566B),
          ),
        ),
        if (!m.onSale) ...[
          const SizedBox(height: KSpacing.xxs),
          Text(
            l10n.vipOffSale(m.tierName),
            key: VipScreen.offSaleKey,
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: vipMuted),
          ),
        ],
      ],
    );
  }
}

/// The sticky bar: the selected tier's price and length at the reading start,
/// and the gold activate button (buy, renew, upgrade; disabled for a lower tier
/// or past the renewal limit) at the end.
class _BottomBar extends StatelessWidget {
  const new({
    required this.tier,
    required this.chargeCoins,
    required this.action,
    required this.busy,
    required this.onPressed,
  });

  final VipTier tier;

  /// What the caller pays now (the renewal price when it applies).
  final int chargeCoins;
  final VipAction action;
  final bool busy;
  final void Function(VipAction) onPressed;

  static const gold = Color(0xFFF5C451);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final enabled =
        !busy && action != VipAction.lower && action != VipAction.renewLimit;
    final label = switch (action) {
      VipAction.buy => l10n.vipPayCoins,
      VipAction.renew => l10n.vipRenew,
      VipAction.upgrade => l10n.vipUpgrade,
      VipAction.lower => l10n.vipLowerTier,
      VipAction.renewLimit => l10n.vipRenewLimit,
    };
    final accent = Color(tier.color);
    const white = Color(0xFFFFFFFF);
    final soft = white.withValues(alpha: 0.78);
    // D258 (owner, reference 40): the package's real value — the daily
    // coins over the length, the level speed-up — and the renewal discount.
    final daily = tier.perks
        .where((p) => p.code == VipPerks.dailyCoins)
        .firstOrNull
        ?.amount;
    final speedup = tier.perks
        .where((p) => p.code == VipPerks.levelSpeedup)
        .firstOrNull
        ?.amount;
    final value = [
      if (daily != null)
        l10n.vipCashback(
          KFormat.grouped(daily * tier.durationDays),
          KFormat.grouped(daily),
        ),
      if (speedup != null) l10n.vipSpeedupLine('$speedup'),
    ].join('، ');
    final discounted = chargeCoins < tier.priceCoins;
    return CustomPaint(
      key: VipScreen.barKey,
      painter: _BarPainter(
        top: Color.lerp(accent, const Color(0xFF000000), 0.5)!,
        bottom: Color.lerp(accent, const Color(0xFF000000), 0.78)!,
        edge: gold,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, _BarPainter.arc + 12, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // «1,000,000 كوينز / 30 يوماً», the number in gold (the list
              // price struck through before a renewal price).
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  if (discounted)
                    Text(
                      KFormat.grouped(tier.priceCoins),
                      key: VipScreen.listPriceKey,
                      style: t.body.copyWith(
                        color: soft,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: soft,
                      ),
                    ),
                  Text(
                    KFormat.grouped(chargeCoins),
                    style: t.title.copyWith(
                      color: gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    l10n.vipPricePer('${tier.durationDays}'),
                    style: t.body.copyWith(color: white),
                  ),
                ],
              ),
              if (value.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  value,
                  key: VipScreen.dailyTotalKey,
                  style: t.caption.copyWith(color: soft),
                ),
              ],
              if (tier.renewalDiscountPercent > 0) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.vipRenewalDiscountLine('${tier.renewalDiscountPercent}'),
                  key: VipScreen.renewalLineKey,
                  style: t.caption.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // One full-width gold pill (no VIP gifting yet).
              Semantics(
                button: true,
                enabled: enabled,
                label: label,
                excludeSemantics: true,
                child: Material(
                  key: VipScreen.ctaKey,
                  color: gold,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enabled ? () => onPressed(action) : null,
                    child: SizedBox(
                      height: 46,
                      width: double.infinity,
                      child: Opacity(
                        opacity: enabled ? 1 : 0.5,
                        child: Center(
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF3A2600),
                                  ),
                                )
                              : Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.label.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF3A2600),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The purchase panel: full width at the screen's bottom, a curved top with
/// a thin gold line along it, a gradient of the tier's colour (reference 40).
class _BarPainter extends CustomPainter {
  new({required this.top, required this.bottom, required this.edge});

  final Color top;
  final Color bottom;
  final Color edge;

  static const double arc = 14;

  Path _curve(Size size) => Path()
    ..moveTo(0, arc)
    ..quadraticBezierTo(size.width / 2, -arc, size.width, arc);

  @override
  void paint(Canvas canvas, Size size) {
    final body = _curve(size)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        _curve(size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = edge.withValues(alpha: 0.8),
      );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.top != top || old.bottom != bottom || old.edge != edge;
}

/// The confirm card (the live family's [KLiveDialogCard]): the tier, the
/// price, the balance, the new end and, for an upgrade, that the days left
/// are not carried over. A short balance turns the primary button into the
/// way to recharge.
class _ConfirmCard extends StatelessWidget {
  const new({
    required this.tier,
    required this.action,
    required this.membership,
    required this.balance,
    required this.chargeCoins,
  });

  final VipTier tier;
  final VipAction action;
  final VipMembership? membership;
  final int? balance;

  /// D258: what is charged (the renewal price when it applies).
  final int chargeCoins;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = KLiveDialogCard.inkOf(context);
    final soft = KLiveDialogCard.softInkOf(context);
    final t = context.textStyles;
    final balance = this.balance;
    final short = balance != null && balance < chargeCoins;
    final now = clock.now();
    final m = membership;
    final base = action == VipAction.renew && m != null ? m.expiresAt : now;
    final until = base.add(Duration(days: tier.durationDays));
    final title = switch (action) {
      VipAction.renew => l10n.vipConfirmRenew(tier.name),
      VipAction.upgrade => l10n.vipConfirmUpgrade(tier.name),
      _ => l10n.vipConfirmBuy(tier.name),
    };
    Widget line(String label, Widget value, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: t.body.copyWith(color: soft)),
          ),
          value,
        ],
      ),
    );
    return KLiveDialogCard(
      key: VipScreen.confirmKey,
      leading: VipBadge(tier: tier, size: 64, animate: false),
      title: title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(
            l10n.vipConfirmPrice,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // D258: a renewal's list price struck through.
                if (chargeCoins < tier.priceCoins) ...[
                  Text(
                    KFormat.grouped(tier.priceCoins),
                    style: t.caption.copyWith(
                      color: soft,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                CoinAmount(
                  chargeCoins,
                  style: t.bodyStrong.copyWith(color: ink),
                ),
              ],
            ),
          ),
          line(
            l10n.vipConfirmBalance,
            balance == null
                ? Icon(Icons.more_horiz_rounded, size: 18, color: ink)
                : CoinAmount(
                    balance,
                    style: t.bodyStrong.copyWith(
                      color: short ? context.palette.error : ink,
                    ),
                  ),
          ),
          line(
            l10n.vipConfirmUntil,
            Text(
              KFormat.date(until, l10n.localeName),
              style: t.bodyStrong.copyWith(color: ink),
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          if (action == VipAction.upgrade && m != null)
            Text(
              l10n.vipUpgradeNote(m.tierName),
              style: t.caption.copyWith(color: soft),
            ),
          Text(l10n.vipManualRenew, style: t.caption.copyWith(color: soft)),
          if (short)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.xs),
              child: Text(
                l10n.vipShort,
                key: VipScreen.shortKey,
                style: t.caption.copyWith(color: context.palette.error),
              ),
            ),
        ],
      ),
      actions: [
        if (short)
          KLiveDialogAction(
            key: VipScreen.rechargeKey,
            label: l10n.vipRecharge,
            primary: true,
            onPressed: () => Navigator.of(context).pop(_Decision.recharge),
          )
        else
          KLiveDialogAction(
            key: VipScreen.payKey,
            label: l10n.vipPay(KFormat.grouped(chargeCoins)),
            primary: true,
            onPressed: () => Navigator.of(context).pop(_Decision.pay),
          ),
        KLiveDialogAction(
          key: VipScreen.cancelKey,
          label: MaterialLocalizations.of(context).cancelButtonLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// D258 (DAILY_COINS, §10.94.5): «الكوينز اليومية: 500» and «استلام» (once a
/// day; «تم الاستلام اليوم» after). A claim credits the wallet and refreshes
/// the balance and the membership.
class VipDailyCoinsRow extends ConsumerStatefulWidget {
  const new({required this.initial, super.key});

  final VipDailyCoins initial;

  static const rowKey = Key('vip.dailyCoins');
  static const claimKey = Key('vip.dailyCoins.claim');

  @override
  ConsumerState<VipDailyCoinsRow> createState() => _VipDailyCoinsRowState();
}

class _VipDailyCoinsRowState extends ConsumerState<VipDailyCoinsRow> {
  late VipDailyCoins _daily = widget.initial;
  bool _busy = false;

  Future<void> _claim() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final result = await ref.read(vipRepositoryProvider).claimDailyCoins();
      if (!mounted) return;
      setState(() => _daily = result.daily);
      ref
        ..invalidate(myVipProvider)
        ..invalidate(liveCoinsProvider);
      if (result.coins > 0) {
        KSnack.success(context, l10n.vipDailyCoinsAdded('${result.coins}'));
      }
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final claimed = _daily.claimedToday;
    return Row(
      key: VipDailyCoinsRow.rowKey,
      children: [
        Expanded(
          child: Text(
            l10n.vipDailyCoins(KFormat.compact(_daily.amount, l10n)),
            // The sheet's own text colour (dark on light, white on dark).
            style: t.body.copyWith(
              color: VipPalette.of(context).text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: KSpacing.sm),
        FilledButton(
          key: VipDailyCoinsRow.claimKey,
          onPressed: claimed || _busy ? null : () => unawaited(_claim()),
          style: FilledButton.styleFrom(
            backgroundColor: vipGold,
            foregroundColor: const Color(0xFF2A1A00),
          ),
          child: Text(
            claimed ? l10n.vipDailyCoinsClaimed : l10n.vipDailyCoinsClaim,
          ),
        ),
      ],
    );
  }
}
