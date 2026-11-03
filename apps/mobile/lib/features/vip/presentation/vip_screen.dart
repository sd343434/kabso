import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What the sticky button does for the tier on screen (the server decides
/// again; D252, CONVENTIONS §10.92.2).
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

/// `/vip` (D252, owner «اصنع صفحة شراء vip»; D252b owner «طبق هذا التصميم
/// ١٠٠٪»): «شراء VIP» in the layout of the owner's reference — the top bar
/// with a VIP-store entry, a hanging crest banner for the selected tier
/// flanked by the adjacent tiers' banners, a curved tier track, the status
/// and upgrade bar, and a crown-topped perks grid — in Kabso's dark purple +
/// gold identity, RTL-correct. The crest and perk thumbnails are placeholder
/// slots (the owner's own art goes there; the reference's eagle crest and
/// gold ornaments are third-party and are not copied). Tiers, prices and
/// perks come from the admin panel; buying is coins only (`POST
/// /me/vip/purchases`).
class VipScreen extends ConsumerStatefulWidget {
  const VipScreen({super.key});

  static const storeKey = Key('vip.store');
  static const statusKey = Key('vip.status');
  static const bannerKey = Key('vip.banner');
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

  Future<void> _start(
    VipTier tier,
    VipAction action,
    VipMembership? membership,
  ) async {
    final balance = ref.read(liveCoinsProvider).value;
    final decision = await showKLiveDialog<_Decision>(
      context,
      builder: (dialog) => _ConfirmCard(
        tier: tier,
        action: action,
        membership: membership,
        balance: balance,
      ),
    );
    if (!mounted) return;
    if (decision == _Decision.recharge) {
      unawaited(context.push(AppRoutes.wallet));
      return;
    }
    if (decision != _Decision.pay) return;
    await _buy(tier);
  }

  Future<void> _buy(VipTier tier) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(vipRepositoryProvider)
          .buy(
            tierId: tier.id,
            priceCoins: tier.priceCoins,
            idempotencyKey: newIdempotencyKey(),
          );
      ref.read(liveCoinsProvider.notifier).set(result.coins);
      ref.invalidate(myVipProvider);
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
    final locale = Localizations.localeOf(context);
    return Theme(
      data: buildAppTheme(brightness: Brightness.dark, locale: locale),
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final l10n = context.l10n;
    final tiers = ref.watch(vipTiersProvider);
    final mine = ref.watch(myVipProvider);
    ref.watch(liveCoinsProvider); // keeps the balance loaded for the bar.
    final list = tiers.value;
    final membership = mine.value;
    final ready = list != null && mine.hasValue;
    final tier = ready ? _selected(list, membership) : null;
    final accent = tier == null ? vipGold : Color(tier.color);
    final now = clock.now();
    final failure = tiers.error ?? mine.error;

    final List<Widget> body;
    if (ready && tier != null) {
      // The caller holds this tier or a higher one now (so its perks are the
      // caller's): the buy button would renew it, not buy or upgrade.
      final action = vipActionFor(tier, membership, list, now);
      final held =
          action == VipAction.renew || action == VipAction.lower;
      body = [
        const VipRail(),
        const SizedBox(height: KSpacing.xs),
        _Crest(tiers: list.tiers, selected: tier),
        const SizedBox(height: KSpacing.md),
        VipTierArc(
          tiers: list.tiers,
          selectedId: tier.id,
          heldId: membership?.tierId,
          onSelect: (t) => setState(() => _selectedId = t.id),
        ),
        const SizedBox(height: KSpacing.md),
        _StatusBlock(membership: membership),
        const SizedBox(height: KSpacing.lg),
        VipUpgradeBar(
          upgradeLabel: _upgradeLabel(l10n, list, membership),
          fill: _upgradeFill(list, membership, now),
          balanceCoins: ref.watch(liveCoinsProvider).value,
        ),
        const SizedBox(height: KSpacing.xl),
        _PerksSection(tier: tier, active: held),
      ];
    } else if (ready) {
      body = [
        const VipRail(),
        const SizedBox(height: KSpacing.xxl),
        Column(
          key: VipScreen.emptyKey,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 56,
              color: Color(0xFF6E6480),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.vipEmpty,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(
                color: const Color(0xFFB9A9C9),
              ),
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

    return Scaffold(
      backgroundColor: vipBackground,
      extendBodyBehindAppBar: true,
      appBar: KAppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: vipGoldBright,
        centerTitle: true,
        title: Text(
          l10n.meHubVip,
          style: context.textStyles.title.copyWith(
            color: vipGoldBright,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            key: VipScreen.storeKey,
            tooltip: l10n.vipStore,
            onPressed: list == null ? null : () => unawaited(_showStore(context, list)),
            icon: const Icon(Icons.storefront_rounded),
            color: vipGoldBright,
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.75),
            radius: 1.1,
            colors: [
              Color.alphaBlend(accent.withValues(alpha: 0.28), vipBackground),
              vipBackground,
              const Color(0xFF070510),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: vipGold,
            backgroundColor: const Color(0xFF17121F),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.xl,
              ),
              children: body,
            ),
          ),
        ),
      ),
      bottomNavigationBar: !ready || tier == null
          ? null
          : _BottomBar(
              tier: tier,
              action: vipActionFor(tier, membership, list, now),
              busy: _busy,
              onPressed: (action) => unawaited(_start(tier, action, membership)),
            ),
    );
  }

  String _upgradeLabel(
    AppLocalizations l10n,
    VipTierList list,
    VipMembership? membership,
  ) {
    final next = _nextTier(list, membership);
    return next == null ? l10n.vipMaxTier : l10n.vipUpgradeTo(next.name);
  }

  /// The next tier up from the caller's current rank (the lowest when not a
  /// member), or null at the top.
  VipTier? _nextTier(VipTierList list, VipMembership? membership) {
    if (list.tiers.isEmpty) return null;
    if (membership == null) return list.tiers.first;
    final held = list.tiers
        .where((t) => t.id == membership.tierId)
        .firstOrNull;
    final level = held?.level ?? 0;
    return list.tiers.where((t) => t.level > level).firstOrNull;
  }

  double _upgradeFill(VipTierList list, VipMembership? membership, DateTime now) {
    if (membership == null || !membership.expiresAt.isAfter(now)) return 0;
    final held = list.tiers
        .where((t) => t.id == membership.tierId)
        .firstOrNull;
    final level = held?.level ?? list.tiers.length;
    return list.tiers.isEmpty ? 0 : level / list.tiers.length;
  }

  Future<void> _showStore(BuildContext context, VipTierList list) {
    final l10n = context.l10n;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17121F),
      showDragHandle: true,
      builder: (context) {
        final t = context.textStyles;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              0,
              KSpacing.lg,
              KSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: vipGold),
                    const SizedBox(width: KSpacing.sm),
                    Text(
                      l10n.vipStore,
                      style: t.title.copyWith(color: vipGoldBright),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  l10n.vipStoreSoon,
                  style: t.body.copyWith(color: const Color(0xFFB9A9C9)),
                ),
                const SizedBox(height: KSpacing.lg),
                Text(
                  l10n.vipRules,
                  style: t.bodyStrong.copyWith(color: vipGoldBright),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.vipRulesBody('${list.maxAheadDays}'),
                  style: t.caption.copyWith(color: const Color(0xFFB9A9C9)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The hanging crest: the selected tier's banner, flanked by the adjacent
/// tiers' banners (dim, smaller) for depth.
class _Crest extends StatelessWidget {
  const _Crest({required this.tiers, required this.selected});

  final List<VipTier> tiers;
  final VipTier selected;

  @override
  Widget build(BuildContext context) {
    final index = tiers.indexWhere((t) => t.id == selected.id);
    final prev = index > 0 ? tiers[index - 1] : null;
    final next = index >= 0 && index < tiers.length - 1 ? tiers[index + 1] : null;
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final centerW = (width * 0.46).clamp(140.0, 168.0);
        final centerH = centerW * 1.4;
        final sideW = centerW * 0.52;
        final sideH = sideW * 1.5;
        return SizedBox(
          height: centerH + 14,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              if (prev != null)
                PositionedDirectional(
                  start: 0,
                  top: 30,
                  child: VipHangingBanner(
                    color: Color(prev.color),
                    width: sideW,
                    height: sideH,
                    label: prev.name,
                    dim: true,
                  ),
                ),
              if (next != null)
                PositionedDirectional(
                  end: 0,
                  top: 30,
                  child: VipHangingBanner(
                    color: Color(next.color),
                    width: sideW,
                    height: sideH,
                    label: next.name,
                    dim: true,
                  ),
                ),
              Semantics(
                key: VipScreen.bannerKey,
                label: selected.name,
                child: Builder(
                  builder: (context) {
                    final hasArt = selected.badgeStill != null ||
                        selected.badgeAnimation != null;
                    return VipHangingBanner(
                      color: Color(selected.color),
                      width: centerW,
                      height: centerH,
                      label: selected.name,
                      // The badge art carries its own name plate; show the
                      // banner's name only for a placeholder tier.
                      showLabel: !hasArt,
                      emblem: Padding(
                        padding: const EdgeInsets.only(top: KSpacing.sm),
                        child: VipBadge(
                          key: VipScreen.emblemKey,
                          tier: selected,
                          size: centerW * (hasArt ? 0.9 : 0.52),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// «حالياً: …» and, for a member, the end date, days left and an off-sale
/// note.
class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.membership});

  final VipMembership? membership;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final m = membership;
    final status = m?.tierName ?? l10n.vipStatusNone;
    return Column(
      key: VipScreen.statusKey,
      children: [
        Text(
          l10n.vipCurrently(status),
          textAlign: TextAlign.center,
          style: t.bodyStrong.copyWith(
            color: vipGoldBright,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (m != null) ...[
          const SizedBox(height: 2),
          Text(
            '${l10n.vipUntil(m.tierName, KFormat.date(m.expiresAt, l10n.localeName))}'
            ' · ${l10n.vipDaysLeft('${m.daysLeft}')}',
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: const Color(0xFFB9A9C9)),
          ),
          if (!m.onSale) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.vipOffSale(m.tierName),
              key: VipScreen.offSaleKey,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: const Color(0xFF9A8CB0)),
            ),
          ],
        ],
      ],
    );
  }
}

/// The crown-topped perks grid for the selected tier.
class _PerksSection extends StatelessWidget {
  const _PerksSection({required this.tier, required this.active});

  final VipTier tier;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final perks = tier.perks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VipCrownHeader(title: l10n.vipPerksTitle(tier.name)),
        const SizedBox(height: KSpacing.sm),
        Text(
          l10n.vipPerksSoon,
          textAlign: TextAlign.center,
          style: context.textStyles.caption.copyWith(
            color: const Color(0xFF9A8CB0),
          ),
        ),
        const SizedBox(height: KSpacing.md),
        if (perks.isEmpty)
          Text(
            l10n.vipPerksEmpty,
            textAlign: TextAlign.center,
            style: context.textStyles.body.copyWith(
              color: const Color(0xFFB9A9C9),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              const gap = KSpacing.sm;
              final cardW = (c.maxWidth - 2 * gap) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: KSpacing.md,
                children: [
                  for (final perk in perks)
                    VipPerkCard(
                      perk: perk,
                      tier: tier,
                      active: active,
                      width: cardW,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// The sticky bar: the selected tier's price and length, and the tier-coloured
/// button (buy, renew, upgrade; disabled for a lower tier or past the renewal
/// limit).
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tier,
    required this.action,
    required this.busy,
    required this.onPressed,
  });

  final VipTier tier;
  final VipAction action;
  final bool busy;
  final void Function(VipAction) onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final color = Color(tier.color);
    final enabled =
        !busy && action != VipAction.lower && action != VipAction.renewLimit;
    final label = switch (action) {
      VipAction.buy => l10n.vipBuy,
      VipAction.renew => l10n.vipRenew,
      VipAction.upgrade => l10n.vipUpgrade,
      VipAction.lower => l10n.vipLowerTier,
      VipAction.renewLimit => l10n.vipRenewLimit,
    };
    final fg = enabled ? vipOnColor(color) : const Color(0xFF8A7CA0);
    return DecoratedBox(
      key: VipScreen.barKey,
      decoration: const BoxDecoration(
        color: Color(0xFF130E1C),
        border: Border(top: BorderSide(color: Color(0xFF2A2233))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoinAmount(
                      tier.priceCoins,
                      size: 18,
                      style: t.bodyStrong.copyWith(
                        color: vipGoldBright,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.vipForDays('${tier.durationDays}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: const Color(0xFFB9A9C9)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Flexible(
                child: Semantics(
                  button: true,
                  enabled: enabled,
                  label: label,
                  excludeSemantics: true,
                  child: Material(
                    key: VipScreen.ctaKey,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    color: enabled ? null : const Color(0xFF2A2233),
                    child: Ink(
                      decoration: enabled
                          ? BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(color, Colors.white, 0.4)!,
                                  color,
                                ],
                              ),
                            )
                          : null,
                      child: InkWell(
                        onTap: enabled ? () => onPressed(action) : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.lg,
                            ),
                            child: Center(
                              widthFactor: 1,
                              heightFactor: 1,
                              child: busy
                                  ? SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: fg,
                                      ),
                                    )
                                  : Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: t.bodyStrong.copyWith(
                                        color: fg,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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

/// The confirm card (the live family's [KLiveDialogCard]): the tier, the
/// price, the balance, the new end and, for an upgrade, that the days left
/// are not carried over. A short balance turns the primary button into the
/// way to recharge.
class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.tier,
    required this.action,
    required this.membership,
    required this.balance,
  });

  final VipTier tier;
  final VipAction action;
  final VipMembership? membership;
  final int? balance;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = KLiveDialogCard.inkOf(context);
    final soft = KLiveDialogCard.softInkOf(context);
    final t = context.textStyles;
    final balance = this.balance;
    final short = balance != null && balance < tier.priceCoins;
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
          Expanded(child: Text(label, style: t.body.copyWith(color: soft))),
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
            CoinAmount(
              tier.priceCoins,
              style: t.bodyStrong.copyWith(color: ink),
            ),
          ),
          line(
            l10n.vipConfirmBalance,
            balance == null
                ? Text('…', style: t.bodyStrong.copyWith(color: ink))
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
            label: l10n.vipPay(KFormat.grouped(tier.priceCoins)),
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
