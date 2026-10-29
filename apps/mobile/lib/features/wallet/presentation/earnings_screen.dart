import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// A share in basis points as a percentage: "65", "12.5", "33.33".
String sharePercent(int bps) {
  if (bps % 100 == 0) return '${bps ~/ 100}';
  final text = (bps / 100).toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

/// `/earnings` «اربح المال» (D164): what the person earned from the gifts
/// they received (`GET /wallet/me/earnings` and `…/history`) — each send's
/// value times the share stored with it. Display only: earnings are not
/// coins; withdrawal stays "Soon" until the payout method is decided (D149).
class EarningsScreen extends ConsumerWidget {
  const new({super.key});

  static const totalKey = Key('earnings.total');
  static const last7Key = Key('earnings.last7');
  static const last30Key = Key('earnings.last30');
  static const withdrawKey = Key('earnings.withdraw');
  static const emptyKey = Key('earnings.empty');

  static Key entryKey(String id) => Key('earnings.entry.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final totals = ref.watch(myEarningsProvider);
    final history = ref.watch(earningHistoryProvider);
    final notifier = ref.read(earningHistoryProvider.notifier);
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    Future<void> refresh() async {
      ref
        ..invalidate(myEarningsProvider)
        ..invalidate(earningHistoryProvider);
      try {
        await ref.read(myEarningsProvider.future);
      } on Object {
        // The page shows the failure with a retry.
      }
    }

    final summary = switch (totals) {
      AsyncValue(:final value?) => Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            const Color(0xFF4DA3FF).withValues(alpha: 0.12),
            p.background,
          ),
          borderRadius: BorderRadius.circular(KRadius.md),
        ),
        child: Column(
          children: [
            Semantics(
              key: totalKey,
              container: true,
              label:
                  '${l10n.earnTotal}: '
                  '${l10n.meHubCoins(KFormat.grouped(value.totalCoins))}',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(
                    l10n.earnTotal,
                    style: t.label.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppIcon(AppIcons.coinGold, size: 28, tint: false),
                      const SizedBox(width: KSpacing.sm),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            KFormat.grouped(value.totalCoins),
                            maxLines: 1,
                            style: t.title.copyWith(
                              color: p.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.md),
            MeStatGrid(
              columns: 2,
              stats: [
                (
                  last7Key,
                  l10n.earnLast7Days,
                  KFormat.grouped(value.last7DaysCoins),
                ),
                (
                  last30Key,
                  l10n.earnLast30Days,
                  KFormat.grouped(value.last30DaysCoins),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            Text(
              l10n.earnDisplayOnly,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
      AsyncValue(:final error?, isLoading: false) => FailureErrorState(
        title: l10n.earnLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(myEarningsProvider),
        compact: true,
      ),
      _ => const Padding(
        padding: EdgeInsets.all(KSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };

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

    return MePage(
      title: l10n.meHubEarn,
      onRefresh: refresh,
      children: [
        summary,
        const SizedBox(height: KSpacing.md),
        MeSoonAction(
          key: withdrawKey,
          label: l10n.earnWithdraw,
          icon: Icons.account_balance_rounded,
          reason: l10n.earnWithdrawSoon,
        ),
        MeSectionTitle(l10n.earnHistoryTitle),
        ...rows,
      ],
    );
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
    final share = l10n.earnShare(
      sharePercent(e.shareBps),
      KFormat.grouped(e.giftCoins),
    );
    return Semantics(
      key: EarningsScreen.entryKey(e.id),
      container: true,
      label:
          '$gift, $from, $where, $when, '
          '${l10n.meHubCoins(amount)}, $share',
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
                  Text(
                    amount,
                    textDirection: TextDirection.ltr,
                    style: t.bodyStrong.copyWith(
                      color: p.success,
                      fontWeight: FontWeight.w700,
                    ),
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
