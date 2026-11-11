import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/features/wallet/data/recharge_points_repository.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The label of a recharge points [reason] (D370).
String rechargePointsReasonLabel(
  AppLocalizations l10n,
  RechargePointsReason reason,
) => switch (reason) {
  RechargePointsReason.rechargeWeb => l10n.rechargePointsReasonWeb,
  RechargePointsReason.rechargeStore => l10n.rechargePointsReasonStore,
  RechargePointsReason.rechargeAgent => l10n.rechargePointsReasonAgent,
  RechargePointsReason.vipRedeem => l10n.rechargePointsReasonVip,
  RechargePointsReason.reversal => l10n.rechargePointsReasonReversal,
  RechargePointsReason.adminAdjust => l10n.rechargePointsReasonAdmin,
  RechargePointsReason.other => l10n.rechargePointsReasonOther,
};

/// `/wallet/recharge-points` (D370, owner 2026-11-11, CONVENTIONS §10.163):
/// «نقاط الشحن» — the balance (never expires; one point per recharged coin),
/// how points are earned, and every change, newest first
/// (`GET /me/recharge-points`). Opened from the wallet's row.
class RechargePointsScreen extends ConsumerWidget {
  const new({super.key});

  static const balanceKey = Key('rechargePoints.balance');
  static const emptyKey = Key('rechargePoints.empty');

  static Key entryKey(String id) => Key('rechargePoints.entry.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final balance = ref.watch(rechargePointsBalanceProvider);
    final value = balance.value;
    return MePage(
      title: l10n.rechargePointsTitle,
      onRefresh: () async {
        ref
          ..invalidate(rechargePointsBalanceProvider)
          ..invalidate(rechargePointsLedgerProvider);
        try {
          await ref.read(rechargePointsLedgerProvider.future);
        } on Object {
          // The page shows the failure with a retry.
        }
      },
      children: [
        Semantics(
          key: RechargePointsScreen.balanceKey,
          container: true,
          child: WalletBalanceCard(
            icon: const Icon(
              Icons.stars_rounded,
              size: 34,
              color: Color(0xFFF5C451),
            ),
            amount: switch (balance) {
              AsyncValue(:final value?) => WalletBigNumber(
                KFormat.grouped(value),
              ),
              AsyncValue(hasError: true) => const WalletBigNumber('–'),
              _ => const KSkeleton(width: 96, height: 32),
            },
            label: l10n.rechargePointsBalanceLabel,
            semanticsLabel: [
              l10n.rechargePointsBalanceLabel,
              if (value != null) l10n.vipPoints(KFormat.grouped(value)),
            ].join(': '),
            tint: const Color(0xFFF5C451),
            footer: Text(
              l10n.rechargePointsHowTo,
              style: context.textStyles.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: KSpacing.md),
        ..._history(context, ref),
      ],
    );
  }

  List<Widget> _history(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ledger = ref.watch(rechargePointsLedgerProvider);
    final notifier = ref.read(rechargePointsLedgerProvider.notifier);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return switch (ledger) {
      AsyncValue(value: FeedItems(:final items)) when items.isEmpty => [
        KEmptyState(
          key: RechargePointsScreen.emptyKey,
          icon: Icons.stars_rounded,
          title: l10n.rechargePointsEmpty,
          message: l10n.rechargePointsEmptyBody,
          compact: true,
        ),
      ],
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        [
          for (final e in items) _EntryTile(entry: e, localeTag: localeTag),
          if (hasMore)
            MeLoadMore(
              failed: loadMoreError != null,
              onLoad: notifier.loadMore,
              itemCount: items.length,
            ),
        ],
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.rechargePointsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(rechargePointsLedgerProvider),
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

class _EntryTile extends StatelessWidget {
  const new({required this.entry, required this.localeTag});

  final RechargePointsEntry entry;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final credit = entry.delta > 0;
    final hue = credit ? p.success : p.error;
    final reason = rechargePointsReasonLabel(l10n, entry.reason);
    final when =
        '${KFormat.date(entry.createdAt, localeTag)} · '
        '${KFormat.time(entry.createdAt, localeTag)}';
    final amount = credit
        ? '+${KFormat.grouped(entry.delta)}'
        : KFormat.grouped(entry.delta);
    final after = l10n.rechargePointsAfter(KFormat.grouped(entry.balanceAfter));
    return Semantics(
      key: RechargePointsScreen.entryKey(entry.id),
      container: true,
      label: '$reason, ${l10n.vipPoints(amount)}, $when, $after',
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
