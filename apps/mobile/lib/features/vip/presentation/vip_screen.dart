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
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
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

/// The text on a tier colour: dark on light tiers, white on dark ones.
Color vipOnColor(Color c) =>
    c.computeLuminance() > 0.4 ? KStatusColors.onStatus : Colors.white;

/// `/vip` (D252, owner: «اصنع صفحة شراء vip … وترتيبه يكون من لوحة كل في
/// اي بي له ميزات وامتيازات مختلفة»): «شراء VIP» in the SVIP family's
/// layout — Kabso's dark theme, the person and their status, a tier
/// switcher in the panel's order, the tier's emblem (its colour; the owner's
/// art when the panel gives one), price and length, its own perks (each
/// «قريباً» until it is built) and a sticky bar with the buy / renew /
/// upgrade button and a confirm card (price, balance, the new end; the way
/// to recharge when the balance is short). Coins only (`POST
/// /me/vip/purchases`).
class VipScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const statusKey = Key('vip.status');
  static const tabsKey = Key('vip.tabs');
  static const emblemKey = Key('vip.emblem');
  static const priceKey = Key('vip.price');
  static const ctaKey = Key('vip.cta');
  static const barKey = Key('vip.bar');
  static const rulesKey = Key('vip.rules');
  static const emptyKey = Key('vip.empty');
  static const confirmKey = Key('vip.confirm');
  static const payKey = Key('vip.confirm.pay');
  static const rechargeKey = Key('vip.confirm.recharge');
  static const cancelKey = Key('vip.confirm.cancel');
  static const shortKey = Key('vip.confirm.short');
  static const offSaleKey = Key('vip.offSale');

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
    final p = context.palette;
    final tiers = ref.watch(vipTiersProvider);
    final mine = ref.watch(myVipProvider);
    // Keeps the balance loaded for the confirm card.
    ref.watch(liveCoinsProvider);
    final list = tiers.value;
    final membership = mine.value;
    final ready = list != null && mine.hasValue;
    final tier = ready ? _selected(list, membership) : null;
    final accent = tier == null ? KBrandColors.gold : Color(tier.color);
    final now = clock.now();
    final failure = tiers.error ?? mine.error;

    final List<Widget> body;
    if (ready && tier != null) {
      body = [
        _Header(membership: membership),
        if (membership != null && !membership.onSale) ...[
          const SizedBox(height: KSpacing.sm),
          _OffSaleNote(membership: membership),
        ],
        const SizedBox(height: KSpacing.lg),
        _TierTabs(
          tiers: list.tiers,
          selectedId: tier.id,
          heldId: membership?.tierId,
          onSelect: (t) => setState(() => _selectedId = t.id),
        ),
        const SizedBox(height: KSpacing.xl),
        _Emblem(tier: tier),
        const SizedBox(height: KSpacing.md),
        _PriceLine(tier: tier),
        const SizedBox(height: KSpacing.xl),
        _Perks(
          tier: tier,
          active:
              membership != null &&
              vipActionFor(tier, membership, list, now) != VipAction.upgrade &&
              vipActionFor(tier, membership, list, now) != VipAction.buy,
        ),
      ];
    } else if (ready) {
      body = [
        _Header(membership: membership),
        const SizedBox(height: KSpacing.xxl),
        Column(
          key: VipScreen.emptyKey,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 56,
              color: p.textTertiary,
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.vipEmpty,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(color: p.textSecondary),
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
      backgroundColor: p.background,
      extendBodyBehindAppBar: true,
      appBar: KAppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        centerTitle: true,
        title: Text(
          l10n.meHubVip,
          style: context.textStyles.title.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            key: VipScreen.rulesKey,
            tooltip: l10n.vipRules,
            onPressed: list == null
                ? null
                : () => unawaited(_showRules(context, list)),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(accent.withValues(alpha: 0.2), p.surfaceRaised),
              p.background,
              p.background,
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
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
              onPressed: (action) =>
                  unawaited(_start(tier, action, membership)),
            ),
    );
  }

  Future<void> _showRules(BuildContext context, VipTierList list) {
    final l10n = context.l10n;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final p = context.palette;
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
                Text(
                  l10n.vipRules,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  l10n.vipRulesBody('${list.maxAheadDays}'),
                  style: t.body.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const new({required this.membership});

  final VipMembership? membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final user = ref.watch(currentUserProvider);
    final name = user == null
        ? ''
        : (user.displayName.isEmpty ? user.username : user.displayName);
    final m = membership;
    final ring = m == null ? p.border : Color(m.tierColor);
    final line = m == null
        ? l10n.vipNotYet
        : l10n.vipUntil(m.tierName, KFormat.date(m.expiresAt, l10n.localeName));
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: KAvatar(name: name, imageUrl: user?.avatarUrl, size: 56),
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.title.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                line,
                key: VipScreen.statusKey,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
              if (m != null)
                Text(
                  l10n.vipDaysLeft('${m.daysLeft}'),
                  style: t.caption.copyWith(color: programGold(context)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OffSaleNote extends StatelessWidget {
  const new({required this.membership});

  final VipMembership membership;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      key: VipScreen.offSaleKey,
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Text(
        context.l10n.vipOffSale(membership.tierName),
        style: context.textStyles.caption.copyWith(color: p.textSecondary),
      ),
    );
  }
}

/// The tier switcher: one pill per tier on sale, in the panel's order (the
/// reading start first), the selected one filled with its colour, the held
/// one marked with a check.
class _TierTabs extends StatelessWidget {
  const new({
    required this.tiers,
    required this.selectedId,
    required this.heldId,
    required this.onSelect,
  });

  final List<VipTier> tiers;
  final String selectedId;
  final String? heldId;
  final ValueChanged<VipTier> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return SingleChildScrollView(
      key: VipScreen.tabsKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tier in tiers)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
              child: Builder(
                builder: (context) {
                  final selected = tier.id == selectedId;
                  final color = Color(tier.color);
                  final on = vipOnColor(color);
                  final held = tier.id == heldId;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: [tier.name, if (held) l10n.vipCurrent].join('، '),
                    excludeSemantics: true,
                    child: Material(
                      key: VipScreen.tabKey(tier.code),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: selected ? color : p.border,
                          width: selected ? 0 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      color: selected ? null : p.surfaceRaised,
                      child: Ink(
                        decoration: selected
                            ? BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color.lerp(color, Colors.white, 0.35)!,
                                    color,
                                  ],
                                ),
                              )
                            : null,
                        child: InkWell(
                          onTap: () => onSelect(tier),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KSpacing.lg,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (held) ...[
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: selected ? on : color,
                                    ),
                                    const SizedBox(width: KSpacing.xs),
                                  ],
                                  Text(
                                    tier.name,
                                    style: t.bodyStrong.copyWith(
                                      color: selected ? on : p.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// The tier's emblem: the owner's art when the panel gives a URL, else a
/// Kabso composition in the tier's colour (a ring, the brand red, the
/// crown and the tier's name) — no third-party art.
class _Emblem extends StatelessWidget {
  const new({required this.tier, this.size = 148});

  final VipTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(tier.color);
    final light = Color.lerp(color, Colors.white, 0.55)!;
    final deep = Color.lerp(color, Colors.black, 0.35)!;
    final url = tier.emblemUrl;
    final drawn = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: size * 0.38,
            color: light,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
            child: Text(
              tier.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.title.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w800,
                fontSize: size * 0.13,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      key: size == 148 ? VipScreen.emblemKey : null,
      label: tier.name,
      excludeSemantics: true,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [color, light, deep, color]),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 36),
            ],
          ),
          padding: EdgeInsets.all(size * 0.055),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: KBrandColors.gradientLive,
              ),
            ),
            child: ClipOval(
              child: url == null
                  ? drawn
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => drawn,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The price in coins and the length.
class _PriceLine extends StatelessWidget {
  const new({required this.tier});

  final VipTier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Semantics(
      key: VipScreen.priceKey,
      label: l10n.vipPriceSemantics(
        KFormat.grouped(tier.priceCoins),
        '${tier.durationDays}',
      ),
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: KSpacing.xs,
        children: [
          CoinAmount(
            tier.priceCoins,
            size: 22,
            style: t.headline.copyWith(
              color: programGold(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l10n.vipForDays('${tier.durationDays}'),
            style: t.body.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Perks extends StatelessWidget {
  const new({required this.tier, required this.active});

  final VipTier tier;

  /// The caller holds this tier (or a higher one) now.
  final bool active;

  static IconData _icon(String code) => switch (code) {
    'BADGE' => Icons.verified_rounded,
    'AVATAR_FRAME' => Icons.account_circle_rounded,
    'CHAT_NAME_COLOR' => Icons.format_color_text_rounded,
    'ENTRY_BANNER' => Icons.flag_rounded,
    'ENTRY_EFFECT' => Icons.auto_awesome_rounded,
    'DAILY_BULLET' => Icons.campaign_rounded,
    'VIEWER_LIST_PRIORITY' => Icons.format_list_numbered_rounded,
    'MONTHLY_GIFT' => Icons.redeem_rounded,
    _ => Icons.star_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final perks = tier.perks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.vipPerksTitle(tier.name),
            style: t.headline.copyWith(color: programGold(context)),
          ),
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.vipPerksSoon,
          style: t.caption.copyWith(color: p.textTertiary),
        ),
        const SizedBox(height: KSpacing.md),
        if (perks.isEmpty)
          Text(
            l10n.vipPerksEmpty,
            style: t.body.copyWith(color: p.textSecondary),
          ),
        for (var i = 0; i < perks.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.sm),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _PerkCard(
                      perk: perks[i],
                      tier: tier,
                      active: active,
                      icon: _icon,
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: i + 1 < perks.length
                        ? _PerkCard(
                            perk: perks[i + 1],
                            tier: tier,
                            active: active,
                            icon: _icon,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PerkCard extends StatelessWidget {
  const new({
    required this.perk,
    required this.tier,
    required this.active,
    required this.icon,
  });

  final VipPerk perk;
  final VipTier tier;
  final bool active;
  final IconData Function(String code) icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final color = Color(tier.color);
    final on = perk.available && active;
    final state = !perk.available
        ? l10n.liveSoon
        : on
        ? l10n.vipPerkActive
        : l10n.vipPerkWith(tier.name);
    final description = perk.description;
    return Semantics(
      key: VipScreen.perkKey(perk.code),
      label: [perk.title, ?description, state].join('، '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.surfaceRaised, p.surface],
          ),
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(
            color: on ? color.withValues(alpha: 0.8) : p.border,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ProgramIconTile(
                  icon: icon(perk.code),
                  hue: perk.available ? color : p.textTertiary,
                ),
                if (!perk.available)
                  PositionedDirectional(
                    end: -6,
                    bottom: -4,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: p.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              perk.title,
              textAlign: TextAlign.center,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
            if (description != null) ...[
              const SizedBox(height: KSpacing.xxs),
              Text(
                description,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ],
            const SizedBox(height: KSpacing.xs),
            ProgramTag(
              state,
              color: on ? color : p.surfaceOverlay,
              onColor: on ? vipOnColor(color) : p.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The sticky bar: the price and the length, and the tier-coloured button
/// (buy, renew, upgrade; disabled for a lower tier or past the renewal
/// limit).
class _BottomBar extends StatelessWidget {
  const new({
    required this.tier,
    required this.action,
    required this.busy,
    required this.onPressed,
  });

  final VipTier tier;
  final VipAction action;
  final bool busy;
  final ValueChanged<VipAction> onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
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
    final fg = enabled ? vipOnColor(color) : p.textTertiary;
    return DecoratedBox(
      key: VipScreen.barKey,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
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
                        color: programGold(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.vipForDays('${tier.durationDays}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: p.textSecondary),
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
                    color: enabled ? null : p.surfaceOverlay,
                    child: Ink(
                      decoration: enabled
                          ? BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(color, Colors.white, 0.45)!,
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
  const new({
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
          Expanded(
            child: Text(label, style: t.body.copyWith(color: soft)),
          ),
          value,
        ],
      ),
    );
    return KLiveDialogCard(
      key: VipScreen.confirmKey,
      leading: _Emblem(tier: tier, size: 72),
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
