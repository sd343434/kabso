import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_cherry_tab.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// A price in [currency] from minor units (cents), Latin digits.
String formatPrice(int minor, String currency) => NumberFormat.simpleCurrency(
  locale: 'en',
  name: currency,
).format(minor / 100);

/// The wallet's two currencies (D177).
enum WalletTab {
  /// The spending currency, the Kabi gold coin (D161).
  gold('gold'),

  /// The host currency, the Kab Cherry (D134).
  cherries('cherries');

  new(this.query);

  /// The `tab` query value of `/wallet`.
  final String query;

  static WalletTab fromQuery(String? q) =>
      values.where((t) => t.query == q).firstOrNull ?? gold;
}

/// `/wallet` (D164; D166 recharge; D177 the owner's «عملة ذهبية وكرزات»):
/// two tabs on a white header — «العملات الذهبية» and «الكرز» — each with a
/// warm balance card.
///
/// - Gold: the real coin balance (`GET /wallet/me`) with a history button
///   (→ `/wallet/history`, the D164 ledger); the wallet promo banners
///   (`GET /home/banners?placement=wallet`, hidden when none); the packages
///   from the server (`GET /wallet/recharge-packages`: 3 per row, bonus,
///   the discount ribbon with the original price struck through, one
///   selected); the selected package's rewards (its bonus coins) and the
///   «احصل على» pill, which stays disabled: «الدفع غير متاح بعد» (B5 — no
///   payment method, no purchase operation exists).
/// - Cherries: [WalletCherryTab].
class WalletScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initialTab = WalletTab.gold});

  final WalletTab initialTab;

  static const balanceKey = Key('wallet.balance');
  static const rechargeKey = Key('wallet.recharge');

  /// D185: «الشحن عبر وكيل» → the agents' directory.
  static const agentsKey = Key('wallet.agents');

  /// D190: «الشحن من الموقع» (hidden unless the server sends the URL).
  static const websiteTopupKey = Key('wallet.websiteTopup');
  static const historyButtonKey = Key('wallet.historyButton');
  static const packagesEmptyKey = Key('wallet.packages.empty');
  static const rewardsKey = Key('wallet.rewards');
  static const rewardsSheetKey = Key('wallet.rewards.sheet');
  static const bannerKey = Key('wallet.banner');

  static Key packageKey(String id) => Key('wallet.package.$id');

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  late WalletTab _tab = widget.initialTab;
  String? _selected;

  Future<void> _refresh() async {
    if (_tab == WalletTab.cherries) {
      await WalletCherryTab.refresh(ref);
      return;
    }
    ref
      ..invalidate(liveCoinsProvider)
      ..invalidate(rechargeOfferProvider)
      ..invalidate(walletBannersProvider);
    try {
      await ref.read(rechargeOfferProvider.future);
    } on Object {
      // The page shows the failure with a retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final gold = _tab == WalletTab.gold;
    return Scaffold(
      backgroundColor: p.surface,
      appBar: KAppBar(
        backgroundColor: p.surfaceRaised,
        centerTitle: true,
        title: Text(l10n.meHubWallet),
      ),
      body: Column(
        children: [
          ColoredBox(
            color: p.surfaceRaised,
            child: WalletTabs(
              labels: [l10n.walletTabGold, l10n.walletTabCherries],
              selected: _tab.index,
              onSelected: (i) => setState(() => _tab = WalletTab.values[i]),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: PageStorageKey('wallet.${_tab.name}'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: KSpacing.xl),
                children: [
                  _HeaderBlock(
                    child: gold
                        ? _goldCard(context)
                        : WalletCherryTab.card(context, ref),
                  ),
                  ...[
                    for (final w
                        in gold
                            ? _gold(context)
                            : WalletCherryTab.children(context, ref))
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _sideGap,
                        ),
                        child: w,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The reference's side margin (11 pt) for the cards under the header.
  static const double _sideGap = KSpacing.md - 1;

  Widget _goldCard(BuildContext context) {
    final l10n = context.l10n;
    final coins = ref.watch(liveCoinsProvider);
    final balance = coins.value;
    return Semantics(
      key: WalletScreen.balanceKey,
      container: true,
      child: WalletBalanceCard(
        icon: const KabsoArtIcon(KabsoArt.coin, size: 34),
        amount: switch (coins) {
          AsyncValue(:final value?) => WalletBigNumber(KFormat.grouped(value)),
          AsyncValue(hasError: true) => const WalletBigNumber('–'),
          _ => const KSkeleton(width: 96, height: 32),
        },
        label: l10n.walletGoldBalance,
        semanticsLabel: [
          l10n.walletGoldBalance,
          if (balance != null) l10n.meHubCoins(KFormat.grouped(balance)),
        ].join(': '),
        tint: KBrandColors.red400,
        action: WalletCardButton(
          key: WalletScreen.historyButtonKey,
          tooltip: l10n.walletHistoryTitle,
          icon: Icons.receipt_long_rounded,
          onPressed: () => unawaited(context.push(AppRoutes.walletHistory)),
        ),
      ),
    );
  }

  void _openBanner(HomeBanner banner) {
    switch (HomeBannerTarget.parse(banner.link)) {
      case HomeBannerRoute(:final location):
        unawaited(context.push<void>(location));
      case HomeBannerLiveTab(tab: final target):
        openLiveHub(context, ref, target);
      case null:
        break;
    }
  }

  List<Widget> _gold(BuildContext context) {
    final l10n = context.l10n;
    final offer = ref.watch(rechargeOfferProvider);
    final banners = ref.watch(walletBannersProvider).value ?? const [];
    final packages = switch (offer) {
      AsyncValue(value: final o?) when o.packages.isEmpty => [
        KEmptyState(
          key: WalletScreen.packagesEmptyKey,
          icon: Icons.inventory_2_outlined,
          title: l10n.walletPackagesEmpty,
          message: l10n.walletRechargeSoon,
          compact: true,
        ),
      ],
      AsyncValue(value: final o?) => _packages(context, o),
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.walletPackagesError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(rechargeOfferProvider),
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
    return [
      if (banners.isNotEmpty)
        Padding(
          key: WalletScreen.bannerKey,
          padding: const EdgeInsets.only(bottom: KSpacing.md),
          child: KHomeBannerCarousel(
            banners: banners,
            onOpen: _openBanner,
            canOpen: (b) => HomeBannerTarget.parse(b.link) != null,
          ),
        ),
      WalletSection(title: l10n.walletRechargeTitle, children: packages),
      // D185: buying coins from a recharge agent (paid outside the app).
      Padding(
        padding: const EdgeInsets.only(top: KSpacing.sm),
        child: RechargeNavRow(
          key: WalletScreen.agentsKey,
          icon: Icons.storefront_rounded,
          title: l10n.rechargeBuyViaAgent,
          subtitle: l10n.rechargeDirectoryHint,
          onTap: () => context.push(AppRoutes.rechargeAgents),
        ),
      ),
      // D190: «الشحن من الموقع» — only when the server sends the website's
      // URL (a server flag, on by default); it opens the browser.
      if (offer.value?.websiteTopupUrl case final url?)
        Padding(
          padding: const EdgeInsets.only(top: KSpacing.sm),
          child: RechargeNavRow(
            key: WalletScreen.websiteTopupKey,
            icon: Icons.language_rounded,
            title: l10n.walletTopupWebsite,
            subtitle: l10n.walletTopupWebsiteHint,
            onTap: () => unawaited(
              ref.read(externalLinkOpenerProvider).open(Uri.parse(url)),
            ),
          ),
        ),
    ];
  }

  List<Widget> _packages(BuildContext context, RechargeOffer offer) {
    final l10n = context.l10n;
    final list = offer.packages;
    final selected =
        list.where((p) => p.id == _selected).firstOrNull ?? list.first;
    final rows = <List<RechargePackage>>[
      for (var i = 0; i < list.length; i += 3)
        list.sublist(i, (i + 3).clamp(0, list.length)),
    ];
    final total = formatPrice(selected.priceMinor, offer.currency);
    final coins = KFormat.grouped(selected.totalCoins);
    return [
      for (final (r, row) in rows.indexed) ...[
        if (r > 0) const SizedBox(height: KSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < 3; c++) ...[
                if (c > 0) const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: c < row.length
                      ? _PackageTile(
                          package: row[c],
                          currency: offer.currency,
                          selected: row[c].id == selected.id,
                          onTap: () => setState(() => _selected = row[c].id),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ],
      if (selected.bonusCoins > 0) ...[
        const SizedBox(height: KSpacing.sm),
        _RewardsRow(package: selected),
      ] else
        const SizedBox(height: KSpacing.lg),
      // B5: no payment method yet and no purchase operation, so the pill
      // stays disabled whatever `purchasesEnabled` says.
      WalletPill(
        key: WalletScreen.rechargeKey,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(l10n.walletGet)),
            const SizedBox(width: KSpacing.xs),
            const KabsoArtIcon(KabsoArt.coin, size: 22),
            const SizedBox(width: KSpacing.xxs),
            Text(coins, textDirection: TextDirection.ltr),
          ],
        ),
        subtitle: l10n.walletTotal(KFormat.bidiIsolate(total)),
        semanticsLabel: l10n.walletGetCoins(coins, total),
        available: false,
        reason: l10n.walletPayUnavailable,
      ),
    ];
  }
}

/// The white block under the tabs that holds the balance card, rounded at
/// the bottom (the reference's header).
class _HeaderBlock extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpacing.md),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(KRadius.lg),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _WalletScreenState._sideGap,
          KSpacing.xs,
          _WalletScreenState._sideGap,
          KSpacing.lg + KSpacing.xs,
        ),
        child: child,
      ),
    ),
  );
}

/// «المكافآت»: the selected package's bonus coins (the only reward a
/// package carries) as a chip; the chevron opens what the package holds.
class _RewardsRow extends StatelessWidget {
  const new({required this.package});

  final RechargePackage package;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final bonus = KFormat.grouped(package.bonusCoins);
    return Semantics(
      key: WalletScreen.rewardsKey,
      button: true,
      label: '${l10n.walletRewards}: ${l10n.walletBonus(bonus)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _showRewards(context),
        borderRadius: BorderRadius.circular(KRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.walletRewards,
                    style: t.title.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      KBrandColors.gold.withValues(alpha: 0.14),
                      p.surfaceRaised,
                    ),
                    borderRadius: BorderRadius.circular(KRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.sm,
                      vertical: KSpacing.xs + 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.ltr,
                      children: [
                        const KabsoArtIcon(KabsoArt.coin, size: 22),
                        const SizedBox(width: KSpacing.xs),
                        Text(
                          'x$bonus',
                          textDirection: TextDirection.ltr,
                          style: t.bodyStrong.copyWith(
                            fontSize: 17,
                            color: programGold(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: KSpacing.xs),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: p.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRewards(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l10n = context.l10n;
        final p = context.palette;
        final t = context.textStyles;
        Widget line(String label, String value, {bool strong = false}) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: t.body.copyWith(color: p.textSecondary),
                    ),
                  ),
                  const KabsoArtIcon(KabsoArt.coin, size: 18),
                  const SizedBox(width: KSpacing.xs),
                  Text(
                    value,
                    textDirection: TextDirection.ltr,
                    style: (strong ? t.title : t.bodyStrong).copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
            );
        return SafeArea(
          child: Padding(
            key: WalletScreen.rewardsSheetKey,
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              0,
              KSpacing.lg,
              KSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.walletRewards,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.sm),
                line(l10n.walletRewardsBase, KFormat.grouped(package.coins)),
                line(
                  l10n.walletRewardsBonus,
                  '+${KFormat.grouped(package.bonusCoins)}',
                ),
                Divider(color: p.border),
                line(
                  l10n.walletRewardsTotal,
                  KFormat.grouped(package.totalCoins),
                  strong: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One coin package: coin icon, coins and the bonus in gold, the original
/// price struck through and the «عرض كبير» ribbon when discounted, the
/// price; selected = Kabso-red outline on a light red tint with a check in
/// the bottom-end corner.
class _PackageTile extends StatelessWidget {
  const new({
    required this.package,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final RechargePackage package;
  final String currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final price = formatPrice(package.priceMinor, currency);
    final original = package.originalPriceMinor;
    final gold = programGold(context);
    final tile = Material(
      color: selected
          ? Color.alphaBlend(p.primary.withValues(alpha: 0.05), p.surfaceRaised)
          : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.sm),
        side: selected
            ? BorderSide(color: p.primary, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.xs,
                  vertical: KSpacing.xs + 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.ltr,
                        children: [
                          const KabsoArtIcon(KabsoArt.coin, size: 16),
                          const SizedBox(width: KSpacing.xxs),
                          Text(
                            KFormat.grouped(package.coins),
                            textDirection: TextDirection.ltr,
                            style: t.bodyStrong.copyWith(
                              fontSize: 15,
                              height: 1.2,
                              color: p.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (package.bonusCoins > 0)
                            Text(
                              '+${KFormat.grouped(package.bonusCoins)}',
                              textDirection: TextDirection.ltr,
                              style: t.bodyStrong.copyWith(
                                fontSize: 15,
                                height: 1.2,
                                color: gold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (original != null)
                      Text(
                        formatPrice(original, currency),
                        style: t.caption.copyWith(
                          height: 1.15,
                          color: p.textTertiary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      price,
                      style: t.label.copyWith(
                        height: 1.2,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: const BorderRadiusDirectional.only(
                      topStart: Radius.circular(KRadius.sm),
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: p.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      key: WalletScreen.packageKey(package.id),
      button: true,
      selected: selected,
      label: [
        l10n.meHubCoins(KFormat.grouped(package.coins)),
        if (package.bonusCoins > 0)
          l10n.walletBonus(KFormat.grouped(package.bonusCoins)),
        price,
        if (original != null) l10n.walletOffer,
      ].join('، '),
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          tile,
          if (original != null)
            // The sticker sits on the tile's top-start corner, above the
            // amount (its text is capped at 1.15× so it never covers it).
            PositionedDirectional(
              top: -KSpacing.md,
              start: -KSpacing.xs,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.15,
                child: Transform.rotate(
                  angle: Directionality.of(context) == TextDirection.rtl
                      ? 0.2
                      : -0.2,
                  child: ProgramTag(l10n.walletOffer, color: p.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
