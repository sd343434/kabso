import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The label of a ledger [reason].
String walletReasonLabel(AppLocalizations l10n, WalletLedgerReason reason) =>
    switch (reason) {
      WalletLedgerReason.adminGrant => l10n.walletReasonAdminGrant,
      WalletLedgerReason.adminRevoke => l10n.walletReasonAdminRevoke,
      WalletLedgerReason.bulletMessage => l10n.walletReasonBulletMessage,
      WalletLedgerReason.familyCreate => l10n.walletReasonFamilyCreate,
      WalletLedgerReason.cpRequest => l10n.walletReasonCpRequest,
      WalletLedgerReason.cpRefund => l10n.walletReasonCpRefund,
      WalletLedgerReason.cpGift => l10n.walletReasonCpGift,
      WalletLedgerReason.liveGift => l10n.walletReasonLiveGift,
      WalletLedgerReason.luckyGift => l10n.walletReasonLuckyGift,
      WalletLedgerReason.luckyGiftWin => l10n.walletReasonLuckyGiftWin,
      WalletLedgerReason.premiumUsernameRent => l10n.walletReasonPremiumRent,
      WalletLedgerReason.premiumUsernameRenew => l10n.walletReasonPremiumRenew,
      WalletLedgerReason.dmGift => l10n.walletReasonDmGift,
      WalletLedgerReason.liveBoost => l10n.walletReasonLiveBoost,
      WalletLedgerReason.liveBoostRefund => l10n.walletReasonLiveBoostRefund,
      WalletLedgerReason.taskReward => l10n.walletReasonTaskReward,
      WalletLedgerReason.checkInReward => l10n.walletReasonCheckIn,
      WalletLedgerReason.eventPrize => l10n.walletReasonEventPrize,
      WalletLedgerReason.other => l10n.walletReasonOther,
    };

/// A signed amount with Latin digits, e.g. "+100" or "-15".
String signedCoins(int delta) =>
    delta > 0 ? '+${KFormat.grouped(delta)}' : KFormat.grouped(delta);

/// A price in [currency] from minor units (cents), Latin digits.
String formatPrice(int minor, String currency) =>
    NumberFormat.simpleCurrency(locale: 'en', name: currency).format(minor / 100);

/// `/wallet` (D164; D166 the recharge screen of the owner's reference): two
/// tabs. «العملات»: the real coin balance (`GET /wallet/me`) with a history
/// shortcut, the coin packages from the server (`GET
/// /wallet/recharge-packages`, 3 per row, bonus coins, the «عرض» ribbon on
/// a discount, one selected) and the full-width «احصل على …» button, which
/// stays disabled with «قريباً»: no purchase is possible yet (B5). «السجل»:
/// every change of the balance (`GET /wallet/me/ledger`), newest first.
class WalletScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const balanceKey = Key('wallet.balance');
  static const rechargeKey = Key('wallet.recharge');
  static const emptyKey = Key('wallet.empty');
  static const historyButtonKey = Key('wallet.historyButton');
  static const packagesEmptyKey = Key('wallet.packages.empty');

  static Key entryKey(String id) => Key('wallet.entry.$id');
  static Key packageKey(String id) => Key('wallet.package.$id');

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  int _tab = 0;
  String? _selected;

  Future<void> _refresh() async {
    ref
      ..invalidate(liveCoinsProvider)
      ..invalidate(walletLedgerProvider)
      ..invalidate(rechargeOfferProvider);
    try {
      await (_tab == 0
          ? ref.read(rechargeOfferProvider.future)
          : ref.read(walletLedgerProvider.future));
    } on Object {
      // The page shows the failure with a retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.meHubWallet),
      ),
      body: Column(
        children: [
          KPrimaryTabs(
            centered: true,
            labels: [l10n.walletTabCoins, l10n.walletHistoryTitle],
            selectedIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.lg,
                  KSpacing.sm,
                  KSpacing.lg,
                  KSpacing.xl,
                ),
                children: _tab == 0 ? _coins(context) : _history(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _coins(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final coins = ref.watch(liveCoinsProvider);
    final offer = ref.watch(rechargeOfferProvider);
    final balance = coins.value;
    final card = Semantics(
      key: WalletScreen.balanceKey,
      container: true,
      label: [
        l10n.walletBalanceLabel,
        if (balance != null) l10n.meHubCoins(KFormat.grouped(balance)),
      ].join(': '),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              Color.alphaBlend(
                KBrandColors.gold.withValues(alpha: 0.28),
                p.surfaceRaised,
              ),
              Color.alphaBlend(
                p.primary.withValues(alpha: 0.10),
                p.surfaceRaised,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(KRadius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppIcon(AppIcons.coinGold, size: 30, tint: false),
                        const SizedBox(width: KSpacing.sm),
                        Flexible(
                          child: switch (coins) {
                            AsyncValue(:final value?) => FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                KFormat.grouped(value),
                                maxLines: 1,
                                style: t.title.copyWith(
                                  color: p.textPrimary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            AsyncValue(hasError: true) => Text(
                              '–',
                              style: t.title.copyWith(color: p.textPrimary),
                            ),
                            _ => const KSkeleton(width: 96, height: 30),
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpacing.xs),
                    Text(
                      l10n.walletBalanceLabel,
                      style: t.label.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: WalletScreen.historyButtonKey,
              tooltip: l10n.walletHistoryTitle,
              onPressed: () => setState(() => _tab = 1),
              icon: Icon(Icons.receipt_long_rounded, color: p.textSecondary),
            ),
          ],
        ),
      ),
    );

    final List<Widget> packages = switch (offer) {
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
    return [card, MeSectionTitle(l10n.walletRechargeTitle), ...packages];
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
      const SizedBox(height: KSpacing.lg),
      // B5: no payment method yet, so the button stays disabled.
      MeSoonAction(
        key: WalletScreen.rechargeKey,
        label: l10n.walletGetCoins(
          KFormat.grouped(selected.totalCoins),
          formatPrice(selected.priceMinor, offer.currency),
        ),
        icon: Icons.add_rounded,
        reason: l10n.walletRechargeSoon,
      ),
    ];
  }

  List<Widget> _history(BuildContext context) {
    final l10n = context.l10n;
    final ledger = ref.watch(walletLedgerProvider);
    final notifier = ref.read(walletLedgerProvider.notifier);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return switch (ledger) {
      AsyncValue(value: FeedItems(:final items)) when items.isEmpty => [
        KEmptyState(
          key: WalletScreen.emptyKey,
          icon: Icons.receipt_long_rounded,
          title: l10n.walletHistoryEmpty,
          message: l10n.walletHistoryEmptyBody,
          compact: true,
        ),
      ],
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        [
          for (final e in items) _LedgerTile(entry: e, localeTag: localeTag),
          if (hasMore)
            MeLoadMore(
              failed: loadMoreError != null,
              onLoad: notifier.loadMore,
              itemCount: items.length,
            ),
        ],
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.walletLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(walletLedgerProvider),
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
  }
}

/// One coin package: coins + bonus, the price, the original price struck
/// through with the «عرض» ribbon when discounted; selected = red outline
/// and a check.
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
      child: Material(
        color: selected
            ? Color.alphaBlend(p.primary.withValues(alpha: 0.08), p.surface)
            : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.md),
          side: BorderSide(
            color: selected ? p.primary : p.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 76),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KSpacing.xs,
                    KSpacing.md,
                    KSpacing.xs,
                    KSpacing.sm,
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
                            const AppIcon(
                              AppIcons.coinGold,
                              size: 16,
                              tint: false,
                            ),
                            const SizedBox(width: KSpacing.xxs),
                            Text(
                              KFormat.grouped(package.coins),
                              style: t.bodyStrong.copyWith(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (package.bonusCoins > 0)
                              Text(
                                '+${KFormat.grouped(package.bonusCoins)}',
                                style: t.bodyStrong.copyWith(color: gold),
                              ),
                          ],
                        ),
                      ),
                      if (original != null)
                        Text(
                          formatPrice(original, currency),
                          style: t.caption.copyWith(
                            color: p.textTertiary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        price,
                        style: t.label.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (original != null)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  child: ProgramTag(l10n.walletOffer, color: p.primary),
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
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const new({required this.entry, required this.localeTag});

  final WalletLedgerEntry entry;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final credit = entry.delta > 0;
    final hue = credit ? p.success : p.error;
    final reason = walletReasonLabel(l10n, entry.reason);
    final when =
        '${KFormat.date(entry.createdAt, localeTag)} · '
        '${KFormat.time(entry.createdAt, localeTag)}';
    final amount = signedCoins(entry.delta);
    final after = l10n.walletBalanceAfter(KFormat.grouped(entry.balanceAfter));
    return Semantics(
      key: WalletScreen.entryKey(entry.id),
      container: true,
      label: '$reason, ${l10n.meHubCoins(amount)}, $when, $after',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hue.withValues(alpha: 0.14),
              ),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(
                  credit ? Icons.south_west_rounded : Icons.north_east_rounded,
                  size: 18,
                  color: hue,
                ),
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(when, style: t.caption.copyWith(color: p.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    textDirection: TextDirection.ltr,
                    style: t.bodyStrong.copyWith(
                      color: hue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    after,
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
