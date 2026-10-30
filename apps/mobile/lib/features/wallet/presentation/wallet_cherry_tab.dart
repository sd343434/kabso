import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// A share in basis points as a percentage: "65", "12.5", "33.33".
String sharePercent(int bps) {
  if (bps % 100 == 0) return '${bps ~/ 100}';
  final text = (bps / 100).toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

/// The wallet's «الكرز» tab (D177; D164's `/earnings` before): the host
/// currency, the Kab Cherry (D134). The numbers are D164's gift earnings —
/// Σ floor(received gift coins × the send's stored share) — shown 1:1 as
/// cherries (one cherry = one coin of the host's share). Display only: no
/// stored balance, nothing is credited, and withdrawal stays «قريباً»
/// until the payout method is decided (D149).
abstract final class WalletCherryTab {
  static const totalKey = Key('earnings.total');
  static const last7Key = Key('earnings.last7');
  static const last30Key = Key('earnings.last30');
  static const withdrawKey = Key('earnings.withdraw');
  static const emptyKey = Key('earnings.empty');

  static Key entryKey(String id) => Key('earnings.entry.$id');

  /// Reloads the totals and the history.
  static Future<void> refresh(WidgetRef ref) async {
    ref
      ..invalidate(myEarningsProvider)
      ..invalidate(earningHistoryProvider);
    try {
      await ref.read(myEarningsProvider.future);
    } on Object {
      // The tab shows the failure with a retry.
    }
  }

  /// The card (inside the page's white header block).
  static Widget card(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final totals = ref.watch(myEarningsProvider);
    if (totals case AsyncValue(:final error?, isLoading: false)) {
      return FailureErrorState(
        title: l10n.earnLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(myEarningsProvider),
        compact: true,
      );
    }
    final value = totals.value;
    String n(int v) => KFormat.grouped(v);
    Widget stat(Key key, String label, int? v) => Expanded(
      child: Semantics(
        key: key,
        container: true,
        label: v == null ? label : '$label: ${l10n.walletCherries(n(v))}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.caption.copyWith(color: p.textSecondary)),
            Row(
              children: [
                const KCherryIcon(size: 16),
                const SizedBox(width: KSpacing.xxs),
                Flexible(
                  child: Text(
                    v == null ? '–' : n(v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: t.bodyStrong.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Semantics(
      key: totalKey,
      container: true,
      child: WalletBalanceCard(
        icon: const KCherryIcon(size: 34),
        amount: value == null
            ? const KSkeleton(width: 96, height: 32)
            : WalletBigNumber(n(value.totalCoins)),
        label: l10n.walletCherryBalance,
        semanticsLabel: [
          l10n.walletCherryBalance,
          if (value != null) l10n.walletCherries(n(value.totalCoins)),
        ].join(': '),
        tint: KBrandColors.red400,
        tintStrength: 0.22,
        footer: Row(
          children: [
            stat(last7Key, l10n.earnLast7Days, value?.last7DaysCoins),
            const SizedBox(width: KSpacing.md),
            stat(last30Key, l10n.earnLast30Days, value?.last30DaysCoins),
          ],
        ),
      ),
    );
  }

  /// Everything under the header block.
  static List<Widget> children(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final history = ref.watch(earningHistoryProvider);
    final notifier = ref.read(earningHistoryProvider.notifier);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final rows = switch (history) {
      AsyncValue(value: FeedItems(:final items)) when items.isEmpty => [
        KEmptyState(
          key: emptyKey,
          icon: Icons.card_giftcard_rounded,
          title: l10n.earnEmpty,
          message: l10n.earnEmptyBody,
          compact: true,
        ),
      ],
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        [
          for (final e in items) _EarningTile(earning: e, localeTag: localeTag),
          if (hasMore)
            MeLoadMore(
              failed: loadMoreError != null,
              onLoad: notifier.loadMore,
              itemCount: items.length,
            ),
        ],
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.earnLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(earningHistoryProvider),
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
      WalletSection(
        children: [
          Text(
            l10n.walletCherryUnit,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.md),
          // D149: no payout method yet, so the pill stays disabled.
          WalletPill(
            key: withdrawKey,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const KCherryIcon(size: 22),
                const SizedBox(width: KSpacing.xs),
                Flexible(child: Text(l10n.walletWithdraw)),
              ],
            ),
            semanticsLabel: l10n.walletWithdraw,
            available: false,
            reason: l10n.earnWithdrawSoon,
          ),
        ],
      ),
      const SizedBox(height: KSpacing.md),
      WalletSectionPiece(title: l10n.earnHistoryTitle),
      for (final row in rows) WalletSectionPiece(child: row),
      const WalletSectionPiece(bottom: true, child: SizedBox.shrink()),
    ];
  }
}

class _EarningTile extends StatelessWidget {
  const new({required this.earning, required this.localeTag});

  final Earning earning;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final e = earning;
    final sender = e.sender;
    final from = sender == null
        ? l10n.earnFromHidden
        : l10n.earnFrom(
            KFormat.bidiIsolate(
              sender.displayName.isEmpty ? sender.username : sender.displayName,
            ),
          );
    final where = e.context == EarningContext.dm
        ? l10n.earnContextDm
        : l10n.earnContextLive;
    final when =
        '${KFormat.date(e.createdAt, localeTag)} · '
        '${KFormat.time(e.createdAt, localeTag)}';
    final gift = l10n.earnGiftLine(KFormat.bidiIsolate(e.giftName), e.quantity);
    final amount = '+${KFormat.grouped(e.coins)}';
    final cherries = KFormat.grouped(e.coins);
    final share = l10n.earnShare(
      sharePercent(e.shareBps),
      KFormat.grouped(e.giftCoins),
    );
    return Semantics(
      key: WalletCherryTab.entryKey(e.id),
      container: true,
      label:
          '$gift, $from, $where, $when, '
          '${l10n.walletCherries(cherries)}, $share',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.primary.withValues(alpha: 0.12),
              ),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(
                  Icons.card_giftcard_rounded,
                  size: 18,
                  color: p.primary,
                ),
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    '$from · $where',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                  Text(when, style: t.caption.copyWith(color: p.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.ltr,
                    children: [
                      Text(
                        amount,
                        textDirection: TextDirection.ltr,
                        style: t.bodyStrong.copyWith(
                          color: p.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: KSpacing.xxs),
                      const KCherryIcon(size: 16),
                    ],
                  ),
                  Text(
                    share,
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
