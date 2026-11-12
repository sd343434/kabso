import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
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
import 'package:kabso_live/features/vip/presentation/vip_carousel.dart';
import 'package:kabso_live/features/vip/presentation/vip_gift_perks.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_ref_parts.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
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

  /// D304: the top bar's title.
  static const titleKey = Key('vip.title');

  /// D258: «من زار ملفي» in the member's sheet.
  static const visitorsKey = Key('vip.visitors');
  static const identityKey = Key('vip.identity');
  static const Key emblemKey = VipTierCard.emblemKey;
  static const ctaKey = Key('vip.cta');
  static const barKey = Key('vip.bar');
  static const emptyKey = Key('vip.empty');
  static const offSaleKey = Key('vip.offSale');
  static const confirmKey = Key('vip.confirm');
  static const payKey = Key('vip.confirm.pay');
  static const rechargeKey = Key('vip.confirm.recharge');
  static const cancelKey = Key('vip.confirm.cancel');
  static const shortKey = Key('vip.confirm.short');

  /// D370 «استبدل بالنقاط»: the purchase panel's two ways to pay, the
  /// points balance line and the confirm card's points line.
  static const payCoinsKey = Key('vip.payWith.coins');
  static const payPointsKey = Key('vip.payWith.points');
  static const pointsBalanceKey = Key('vip.points.balance');
  static const pointsPriceKey = Key('vip.points.price');
  static const confirmPointsKey = Key('vip.confirm.points');

  static Key tabKey(String code) => Key('vip.tab.$code');
  static Key perkKey(String code) => Key('vip.perk.$code');

  /// D258: the package's value line in the bottom bar.
  static const dailyTotalKey = Key('vip.dailyTotal');

  /// D258: the renewal discount line, and the list price struck through.
  static const renewalLineKey = Key('vip.renewalLine');
  static const listPriceKey = Key('vip.listPrice');

  /// D258: the page's background.
  static const backdropKey = Key('vip.backdrop');

  /// D304 (owner, reference): the page's background — a deep navy behind
  /// the cards fading into the dark plum of the reference (no longer the
  /// tier's colour, D258).
  static const List<Color> backdrop = [KVipRef.pageTop, KVipRef.page];

  @override
  ConsumerState<VipScreen> createState() => _VipScreenState();
}

enum _Decision { pay, recharge }

class _VipScreenState extends ConsumerState<VipScreen> {
  String? _selectedId;
  bool _busy = false;

  /// D370: «استبدل بالنقاط» chosen (only for a tier with a points price).
  bool _withPoints = false;

  VipTier? _selected(VipTierList list, VipMembership? membership) {
    if (list.tiers.isEmpty) return null;
    final id = _selectedId ?? membership?.tierId;
    return list.tiers.where((t) => t.id == id).firstOrNull ?? list.tiers.first;
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(vipTiersProvider)
      ..invalidate(myVipProvider)
      ..invalidate(liveCoinsProvider)
      ..invalidate(rechargePointsBalanceProvider);
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

  /// D370 (§10.163.3): what redeeming [tier] with points costs now — the
  /// renewal's points price when the server quotes it, else the tier's;
  /// null when the tier cannot be redeemed.
  int? _pointsPriceOf(VipTier tier) {
    final renewal = ref.read(myVipRenewalProvider).value;
    if (renewal != null && renewal.tierId == tier.id) {
      return renewal.pricePoints ?? tier.pricePoints;
    }
    return tier.pricePoints;
  }

  /// D370: «استبدل بالنقاط» is on for [tier] (it has a points price).
  bool _pointsFor(VipTier tier) => _withPoints && tier.pricePoints != null;

  Future<void> _start(
    VipTier tier,
    VipAction action,
    VipMembership? membership,
  ) async {
    final withPoints = _pointsFor(tier);
    final balance = withPoints
        ? ref.read(rechargePointsBalanceProvider).value
        : ref.read(liveCoinsProvider).value;
    final price = withPoints ? _pointsPriceOf(tier)! : _priceOf(tier);
    final decision = await showKLiveDialog<_Decision>(
      context,
      builder: (dialog) => _ConfirmCard(
        tier: tier,
        action: action,
        membership: membership,
        balance: balance,
        chargeCoins: price,
        points: withPoints,
      ),
    );
    if (!mounted) return;
    if (decision == _Decision.recharge) {
      unawaited(context.push(AppRoutes.wallet));
      return;
    }
    if (decision != _Decision.pay) return;
    await _buy(tier, price, points: withPoints);
  }

  Future<void> _buy(VipTier tier, int price, {bool points = false}) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final VipMembership membership;
      final String done;
      if (points) {
        // D370 «استبدل بالنقاط»: the coins are not touched.
        final result = await ref
            .read(vipRepositoryProvider)
            .redeemWithPoints(
              tierId: tier.id,
              pricePoints: price,
              idempotencyKey: newIdempotencyKey(),
            );
        membership = result.membership;
        ref
          ..invalidate(rechargePointsBalanceProvider)
          ..invalidate(rechargePointsLedgerProvider);
        done = l10n.vipRedeemDone(
          membership.tierName,
          KFormat.date(membership.expiresAt, l10n.localeName),
        );
      } else {
        final result = await ref
            .read(vipRepositoryProvider)
            .buy(
              tierId: tier.id,
              priceCoins: price,
              idempotencyKey: newIdempotencyKey(),
            );
        membership = result.membership;
        ref.read(liveCoinsProvider.notifier).set(result.coins);
        done = l10n.vipDone(
          membership.tierName,
          KFormat.date(membership.expiresAt, l10n.localeName),
        );
      }
      ref
        ..invalidate(myVipProvider)
        ..invalidate(myVipRenewalProvider);
      if (!mounted) return;
      KSnack.info(context, done);
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
        } else if (code == ErrorCode.insufficientRechargePoints) {
          ref.invalidate(rechargePointsBalanceProvider);
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
            'no_points_price' => l10n.vipErrorNoPointsPrice,
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
    // D370: the recharge points for «استبدل بالنقاط».
    final points = ref.watch(rechargePointsBalanceProvider).value;
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
      final active = membership != null && membership.expiresAt.isAfter(now);
      body = [
        // D304 (owner, reference «استنسخ التصميم ١٠٠٪»): the tier cards, the
        // «امتيازات VIP» header with its count, the hexagon grid.
        VipTierCarousel(
          tiers: list.tiers,
          selectedId: tier.id,
          ownedId: active ? membership.tierId : null,
          lockedIds: {
            for (final t in list.tiers)
              if (vipActionFor(t, membership, list, now) == VipAction.lower)
                t.id,
          },
          captionOf: (t) => active && membership.tierId == t.id
              ? l10n.vipUntil(
                  t.name,
                  KFormat.date(membership.expiresAt, l10n.localeName),
                )
              : '${KFormat.grouped(t.priceCoins)} '
                    '${l10n.vipPricePer('${t.durationDays}')}',
          onSelect: (t) {
            if (t.id != _selectedId) setState(() => _selectedId = t.id);
          },
        ),
        const SizedBox(
          height:
              KVipRef.headerGap - KVipRef.dividerMiddle - KVipRef.dividerEnd,
        ),
        // D374 (§10.166.5): the tier's EFFECTIVE perks (its own and the
        // lower tiers'), «قريباً» on the ones not built; x/y counts them
        // against the top tier's.
        VipPrivilegesHeader(
          count: tier.effectivePerks.length,
          total: list.tiers
              .map((t) => t.effectivePerks.length)
              .reduce(math.max),
        ),
        const SizedBox(height: KVipRef.gridGap),
        VipHexPerkGrid(tier: tier, active: held),
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
    return Scaffold(
      backgroundColor: KVipRef.page,
      body: DecoratedBox(
        key: VipScreen.backdropKey,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: VipScreen.backdrop,
            stops: [0.35, 0.45],
          ),
        ),
        // D304: the top bar under the status bar (D142's gap), then the
        // tier pills below it.
        child: KTopSafeArea(
          child: Column(
            children: [
              _TopBar(
                title: l10n.vipPageTitle,
                // «الخاص بي VIP ›» at the end edge (members only).
                trailing: ready && membership != null
                    ? VipMyChip(
                        key: VipScreen.statusKey,
                        label: l10n.vipMine,
                        onTap: () => unawaited(_showMine(membership)),
                      )
                    : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // D304: the cards 16 pt under the top bar.
                    padding: const EdgeInsets.only(
                      top: KSpacing.lg,
                      bottom: KSpacing.xl,
                    ),
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
              chargePoints: _pointsPriceOf(tier),
              pointsBalance: points,
              withPoints: _pointsFor(tier),
              onPayWith: (withPoints) =>
                  setState(() => _withPoints = withPoints),
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
  Future<void> _showMine(VipMembership membership) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VipPalette.of(context).sheet,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
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
              // D378: «هويتي المميزة» (signature, golden ID, username).
              if (VipIdentityScreen.hasAny(
                vipLookOf(
                  UserVip(
                    tier: membership.tierCode,
                    rank: 0,
                    color: membership.tierColor,
                  ),
                  ref.read(vipTiersProvider).value,
                ),
              ))
                ListTile(
                  key: VipScreen.identityKey,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(context.l10n.vipIdentityEntry),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheet).pop();
                    unawaited(context.push(AppRoutes.vipIdentity));
                  },
                ),
              // D374: the daily coins row is gone (the owner removed
              // DAILY_COINS, 2026-11-11).
              // D381: what the gift, CP, support, rocket and voice perks
              // give now, and «هدية مؤجلة».
              VipPerksNowSection(
                now: membership.perksNow,
                onOpenScheduled: () {
                  Navigator.of(sheet).pop();
                  openVipScheduledGifts(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D304: the page's top bar — back at the reading start (mirrors in RTL),
/// «في آي بي» centred, «الخاص بي VIP» at the end for a member.
class _TopBar extends StatelessWidget {
  const new({required this.title, this.trailing});

  final String title;

  /// «الخاص بي VIP» (members), at the end edge.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = VipPalette.of(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: KMetrics.topBarMaxTextScale,
      child: SizedBox(
        height: KMetrics.topBarHeight,
        child: NavigationToolbar(
          trailing: trailing,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: palette.text,
              size: 28,
            ),
          ),
          middle: Semantics(
            header: true,
            child: Text(
              title,
              key: VipScreen.titleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.title.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    this.chargePoints,
    this.pointsBalance,
    this.withPoints = false,
    this.onPayWith,
  });

  final VipTier tier;

  /// What the caller pays now (the renewal price when it applies).
  final int chargeCoins;

  /// D370: the points price now (null: not redeemable), the caller's
  /// recharge points (null while loading), whether «استبدل بالنقاط» is on,
  /// and the switch between the two ways to pay.
  final int? chargePoints;
  final int? pointsBalance;
  final bool withPoints;
  final ValueChanged<bool>? onPayWith;
  final VipAction action;
  final bool busy;
  final void Function(VipAction) onPressed;

  static const gold = Color(0xFFF5C451);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final allowed = action != VipAction.lower && action != VipAction.renewLimit;
    final points = withPoints ? chargePoints : null;
    final balance = pointsBalance;
    // D370: short of points — the button says so and stays off.
    final pointsShort =
        points != null && allowed && balance != null && balance < points;
    final enabled = !busy && allowed && !pointsShort;
    final label = pointsShort
        ? l10n.vipPointsShort
        : switch (action) {
            VipAction.buy =>
              points != null ? l10n.vipPayPoints : l10n.vipPayCoins,
            VipAction.renew => l10n.vipRenew,
            VipAction.upgrade => l10n.vipUpgrade,
            VipAction.lower => l10n.vipLowerTier,
            VipAction.renewLimit => l10n.vipRenewLimit,
          };
    const white = Color(0xFFFFFFFF);
    final soft = white.withValues(alpha: 0.78);
    // D258 (owner, reference 40): the package's real value — the level
    // speed-up (D374: with inheritance; the daily coins were removed) — and
    // the renewal discount.
    final speedup = tier.effectivePerks
        .where((p) => p.code == VipPerks.levelSpeedup)
        .firstOrNull
        ?.number;
    final value = [if (speedup != null) l10n.vipSpeedupLine('$speedup')]
        .join('، ');
    final discounted = points != null
        ? points < (tier.pricePoints ?? points)
        : chargeCoins < tier.priceCoins;
    // D304 (owner: «شريط الشراء في الاسفل اجعله بطريقة اجمل»): a raised navy
    // panel under a gold curve (echoing the divider over the perks), the
    // price in large gold digits by the coin, the discount as a gold chip,
    // the value line muted, and a rich gold button. Texts and behaviour
    // unchanged.
    return CustomPaint(
      key: VipScreen.barKey,
      painter: const _BarPainter(),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: KSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            _BarPainter.arc + 16,
            20,
            KSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // D370: «ادفع بالعملات الذهبية» | «استبدل بالنقاط», only for
              // a tier the owner priced in points.
              if (chargePoints != null && onPayWith != null) ...[
                VipPayWithSwitch(withPoints: withPoints, onChanged: onPayWith!),
                const SizedBox(height: 12),
              ],
              // «🪙 1,000,000 كوينز / 30 يوماً» (the list price struck
              // through before a renewal price).
              Wrap(
                key: points != null ? VipScreen.pointsPriceKey : null,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (points != null)
                    const Icon(Icons.stars_rounded, size: 22, color: gold)
                  else
                    const KabsoArtIcon(KabsoArt.coin, size: 22),
                  if (discounted)
                    Text(
                      KFormat.grouped(
                        points != null
                            ? (tier.pricePoints ?? points)
                            : tier.priceCoins,
                      ),
                      key: VipScreen.listPriceKey,
                      style: t.body.copyWith(
                        color: soft,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: soft,
                      ),
                    ),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFF6D0),
                        Color(0xFFF8D46A),
                        Color(0xFFD9A23A),
                      ],
                    ).createShader(rect),
                    child: Text(
                      KFormat.grouped(points ?? chargeCoins),
                      style: t.headline.copyWith(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: white,
                      ),
                    ),
                  ),
                  Text(
                    points != null
                        ? l10n.vipPointsPer('${tier.durationDays}')
                        : l10n.vipPricePer('${tier.durationDays}'),
                    style: t.body.copyWith(fontSize: 13, color: soft),
                  ),
                ],
              ),
              // D370: «رصيدك: 2,500,000 نقطة» and how points are earned.
              if (points != null) ...[
                const SizedBox(height: 6),
                Text(
                  balance == null
                      ? l10n.vipPointsHint
                      : '${l10n.vipPointsBalance(KFormat.grouped(balance))}'
                            ' · ${l10n.vipPointsHint}',
                  key: VipScreen.pointsBalanceKey,
                  style: t.caption.copyWith(
                    color: pointsShort ? const Color(0xFFFF8A80) : soft,
                  ),
                ),
              ],
              if (tier.renewalDiscountPercent > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    border: Border.all(color: gold.withValues(alpha: 0.55)),
                  ),
                  child: Text(
                    l10n.vipRenewalDiscountLine(
                      '${tier.renewalDiscountPercent}',
                    ),
                    key: VipScreen.renewalLineKey,
                    style: t.caption.copyWith(
                      color: gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (value.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  value,
                  key: VipScreen.dailyTotalKey,
                  style: t.caption.copyWith(
                    color: white.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Semantics(
                button: true,
                enabled: enabled,
                label: label,
                excludeSemantics: true,
                child: _GoldButton(
                  key: VipScreen.ctaKey,
                  enabled: enabled,
                  busy: busy,
                  label: label,
                  onTap: () => onPressed(action),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D304: the bar's button — a gold gradient pill with a soft inner
/// highlight and a warm glow; muted (still a pill, no glow) when disabled.
class _GoldButton extends StatelessWidget {
  const new({
    required this.enabled,
    required this.busy,
    required this.label,
    required this.onTap,
    super.key,
  });

  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  static const ink = Color(0xFF3A2600);

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final live = enabled || busy;
    final shape = BorderRadius.circular(KRadius.pill);
    // Owner 2026-11-11 («اصغر وبشكل الطف»): a smaller, centred button.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: live
                ? const [
                    BoxShadow(
                      color: Color(0x33F5C451),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: shape,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: live
                      ? const [
                          Color(0xFFFFE9A3),
                          Color(0xFFF5C451),
                          Color(0xFFD99A2B),
                        ]
                      : const [Color(0xFF4A4658), Color(0xFF3A3646)],
                ),
                border: Border.all(
                  color: live
                      ? const Color(0xFFFFF3C4)
                      : const Color(0x33F5C451),
                  width: 0.8,
                ),
              ),
              child: InkWell(
                onTap: enabled ? onTap : null,
                child: SizedBox(
                  height: 42,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The inner highlight over the top half.
                      if (live)
                        Positioned(
                          top: 1,
                          left: 14,
                          right: 14,
                          height: 17,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: shape,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFFFFFFFF)
                                      .withValues(alpha: 0.45),
                                  const Color(0xFFFFFFFF).withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (busy)
                        const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ink,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.label.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: live ? ink : const Color(0xFFB9B1C6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The purchase panel: a soft shadow over the page, a gentle curve on top
/// with a thin gold line fading to the sides (the divider's language), and a
/// navy → plum gradient.
class _BarPainter extends CustomPainter {
  const new();

  static const double arc = 12;

  Path _curve(Size size) => Path()
    ..moveTo(0, arc)
    ..quadraticBezierTo(size.width / 2, -arc, size.width, arc);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final body = _curve(size)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      // The soft shadow cast upward over the perks.
      ..drawPath(
        body.shift(const Offset(0, -4)),
        Paint()
          ..color = const Color(0x8C000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      )
      ..drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E2443), Color(0xFF171A2C), Color(0xFF15131C)],
            stops: [0, 0.45, 1],
          ).createShader(rect),
      )
      // A faint sheen just under the curve.
      ..drawPath(
        _curve(size).shift(const Offset(0, 3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0x142E3A66)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawPath(
        _curve(size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = const LinearGradient(
            colors: [
              Color(0x40E6C873),
              Color(0xFFCFBC87),
              Color(0xFFF3ECB3),
              Color(0xFFCFBC87),
              Color(0x40E6C873),
            ],
            stops: [0, 0.27, 0.5, 0.73, 1],
          ).createShader(rect),
      );
  }

  @override
  bool shouldRepaint(_BarPainter old) => false;
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
    this.points = false,
  });

  final VipTier tier;
  final VipAction action;
  final VipMembership? membership;

  /// The coins, or with [points] the recharge points (null while loading).
  final int? balance;

  /// D258: what is charged (the renewal price when it applies); with
  /// [points] (D370) the points price.
  final int chargeCoins;

  /// D370: «استبدل بالنقاط» — the amounts are recharge points.
  final bool points;

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
            key: points ? VipScreen.confirmPointsKey : null,
            points
                ? Text(
                    l10n.vipPoints(KFormat.grouped(chargeCoins)),
                    style: t.bodyStrong.copyWith(color: ink),
                  )
                : Row(
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
            points ? l10n.vipConfirmPoints : l10n.vipConfirmBalance,
            balance == null
                ? Icon(Icons.more_horiz_rounded, size: 18, color: ink)
                : points
                ? Text(
                    l10n.vipPoints(KFormat.grouped(balance)),
                    style: t.bodyStrong.copyWith(
                      color: short ? context.palette.error : ink,
                    ),
                  )
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
                points ? l10n.errorInsufficientRechargePoints : l10n.vipShort,
                key: VipScreen.shortKey,
                style: t.caption.copyWith(color: context.palette.error),
              ),
            ),
        ],
      ),
      actions: [
        // D370: points cannot be bought — short of points, only cancel.
        if (short && !points)
          KLiveDialogAction(
            key: VipScreen.rechargeKey,
            label: l10n.vipRecharge,
            primary: true,
            onPressed: () => Navigator.of(context).pop(_Decision.recharge),
          )
        else if (!short)
          KLiveDialogAction(
            key: VipScreen.payKey,
            label: points
                ? l10n.vipRedeem(KFormat.grouped(chargeCoins))
                : l10n.vipPay(KFormat.grouped(chargeCoins)),
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

/// D370 (owner: «استبدل بالنقاط» beside «ادفع بالعملات الذهبية»): the
/// purchase panel's two ways to pay — a dark track with two pills, the chosen
/// one gold (the bar's button language), each with its icon (the coin, the
/// points star). Shown only for a tier the owner priced in points.
class VipPayWithSwitch extends StatelessWidget {
  const new({required this.withPoints, required this.onChanged, super.key});

  final bool withPoints;
  final ValueChanged<bool> onChanged;

  static const _gold = Color(0xFFF5C451);
  static const _ink = Color(0xFF3A2600);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    Widget pill({
      required Key key,
      required bool selected,
      required Widget icon,
      required String label,
      required bool points,
    }) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(points),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.pill),
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFE9A3), _gold, Color(0xFFD99A2B)],
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? _ink
                          : const Color(0xFFFFFFFF).withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      label: l10n.vipPayWith,
      // Owner 2026-11-11 («اصغر وبشكل الطف»): a smaller, centred switch.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(KRadius.pill),
              border: Border.all(
                color: _gold.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                pill(
                  key: VipScreen.payCoinsKey,
                  selected: !withPoints,
                  icon: const KabsoArtIcon(KabsoArt.coin, size: 14),
                  label: l10n.vipPayCoins,
                  points: false,
                ),
                pill(
                  key: VipScreen.payPointsKey,
                  selected: withPoints,
                  icon: Icon(
                    Icons.stars_rounded,
                    size: 15,
                    color: withPoints ? _ink : _gold,
                  ),
                  label: l10n.vipPayPoints,
                  points: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
