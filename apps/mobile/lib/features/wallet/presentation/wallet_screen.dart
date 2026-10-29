import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
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
      WalletLedgerReason.other => l10n.walletReasonOther,
    };

/// A signed amount with Latin digits, e.g. "+100" or "-15".
String signedCoins(int delta) =>
    delta > 0 ? '+${KFormat.grouped(delta)}' : KFormat.grouped(delta);

/// `/wallet` (D164): the real coin balance (`GET /wallet/me`) and every
/// change of it (`GET /wallet/me/ledger`), newest first. Recharge stays
/// "Soon": no payment method is decided yet (B5).
class WalletScreen extends ConsumerWidget {
  const new({super.key});

  static const balanceKey = Key('wallet.balance');
  static const rechargeKey = Key('wallet.recharge');
  static const emptyKey = Key('wallet.empty');

  static Key entryKey(String id) => Key('wallet.entry.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final coins = ref.watch(liveCoinsProvider);
    final ledger = ref.watch(walletLedgerProvider);
    final notifier = ref.read(walletLedgerProvider.notifier);
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    Future<void> refresh() async {
      ref
        ..invalidate(liveCoinsProvider)
        ..invalidate(walletLedgerProvider);
      try {
        await ref.read(walletLedgerProvider.future);
      } on Object {
        // The list shows the failure with a retry.
      }
    }

    final balance = coins.value;
    final card = Semantics(
      key: balanceKey,
      container: true,
      label: [
        l10n.walletBalanceLabel,
        if (balance != null) l10n.meHubCoins(KFormat.grouped(balance)),
      ].join(': '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            p.primary.withValues(alpha: 0.10),
            p.background,
          ),
          borderRadius: BorderRadius.circular(KRadius.md),
        ),
        child: Column(
          children: [
            Text(
              l10n.walletBalanceLabel,
              style: t.label.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(AppIcons.coinGold, size: 28, tint: false),
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
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
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
          ],
        ),
      ),
    );

    final history = switch (ledger) {
      AsyncValue(value: FeedItems(:final items)) when items.isEmpty => [
        KEmptyState(
          key: emptyKey,
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

    return MePage(
      title: l10n.meHubWallet,
      onRefresh: refresh,
      children: [
        card,
        const SizedBox(height: KSpacing.md),
        MeSoonAction(
          key: rechargeKey,
          label: l10n.walletRecharge,
          icon: Icons.add_rounded,
          reason: l10n.walletRechargeSoon,
        ),
        MeSectionTitle(l10n.walletHistoryTitle),
        ...history,
      ],
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
