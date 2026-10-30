import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';
import 'package:kabso_live/features/wallet/presentation/cherry_withdraw_sheet.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_parts.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// A share in basis points as a percentage: "65", "12.5", "33.33".
String sharePercent(int bps) {
  if (bps % 100 == 0) return '${bps ~/ 100}';
  final text = (bps / 100).toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

/// A signed cherry amount with Latin digits, e.g. "+650" or "-9,090,910".
String signedCherries(int delta) =>
    delta > 0 ? '+${KFormat.grouped(delta)}' : KFormat.grouped(delta);

/// The wallet's «الكرز» tab (D177; D179: a real balance). The host currency,
/// the Kab Cherry (D134): the cherry ledger (`GET /wallet/me/cherries`,
/// `/ledger`) — credited with each gift received (coins × the gift's share
/// × 10) and with an agency's commissions — the withdrawal requests and
/// «سحب», which opens the request sheet (paid by hand by the team: no
/// payment provider yet). The in-room cherry score is another number.
abstract final class WalletCherryTab {
  static const totalKey = Key('earnings.total');
  static const last7Key = Key('earnings.last7');
  static const last30Key = Key('earnings.last30');
  static const valueKey = Key('cherries.value');
  static const withdrawKey = Key('earnings.withdraw');
  static const pendingKey = Key('cherries.pending');
  static const emptyKey = Key('earnings.empty');

  /// D184: the task cherries still locked for withdrawal.
  static const lockedKey = Key('cherries.taskLocked');

  static Key entryKey(String id) => Key('earnings.entry.$id');
  static Key withdrawalKey(String id) => Key('cherries.withdrawal.$id');

  /// Reloads the balance, the history and the requests.
  static Future<void> refresh(WidgetRef ref) async {
    ref
      ..invalidate(myCherriesProvider)
      ..invalidate(cherryLedgerProvider)
      ..invalidate(myWithdrawalsProvider);
    try {
      await ref.read(myCherriesProvider.future);
    } on Object {
      // The tab shows the failure with a retry.
    }
  }

  /// The card (inside the page's white header block).
  static Widget card(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final load = ref.watch(myCherriesProvider);
    if (load case AsyncValue(:final error?, isLoading: false)) {
      return FailureErrorState(
        title: l10n.earnLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(myCherriesProvider),
        compact: true,
      );
    }
    final w = load.value;
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
    final value = w == null
        ? null
        : l10n.cherryValue(
            KFormat.bidiIsolate(formatPrice(w.valueMinor, w.payout.currency)),
          );
    final held = w == null || w.heldCherries == 0
        ? null
        : l10n.cherryHeld(KFormat.bidiIsolate(n(w.heldCherries)));
    // D184 (CONVENTIONS §10.46.1): task cherries wait for the owner's
    // earnings condition before they can be withdrawn.
    final locked = w == null || w.lockedTaskCherries <= 0
        ? null
        : l10n.cherryTaskLocked(KFormat.bidiIsolate(n(w.lockedTaskCherries)));

    return Semantics(
      key: totalKey,
      container: true,
      child: WalletBalanceCard(
        icon: const KCherryIcon(size: 34),
        amount: w == null
            ? const KSkeleton(width: 96, height: 32)
            : WalletBigNumber(n(w.cherries)),
        label: l10n.walletCherryBalance,
        semanticsLabel: [
          l10n.walletCherryBalance,
          if (w != null) l10n.walletCherries(n(w.cherries)),
          ?value,
          ?held,
          ?locked,
        ].join(': '),
        tint: KBrandColors.red400,
        tintStrength: 0.22,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: Text(
                  [value, ?held].join(' · '),
                  key: valueKey,
                  style: t.label.copyWith(color: p.textSecondary),
                ),
              ),
            if (locked != null)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_clock_rounded,
                      size: 16,
                      color: p.textSecondary,
                    ),
                    const SizedBox(width: KSpacing.xs),
                    Expanded(
                      child: Text(
                        locked,
                        key: lockedKey,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                stat(last7Key, l10n.earnLast7Days, w?.earnedLast7Days),
                const SizedBox(width: KSpacing.md),
                stat(last30Key, l10n.earnLast30Days, w?.earnedLast30Days),
              ],
            ),
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
    final wallet = ref.watch(myCherriesProvider).value;
    final history = ref.watch(cherryLedgerProvider);
    final notifier = ref.read(cherryLedgerProvider.notifier);
    final requests = ref.watch(myWithdrawalsProvider).value ?? const [];
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
          for (final e in items) _CherryTile(entry: e, localeTag: localeTag),
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
          onRetry: () => ref.invalidate(cherryLedgerProvider),
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
    final payout = wallet?.payout;
    final pending = wallet?.pendingWithdrawal;
    return [
      WalletSection(
        children: [
          Text(
            payout == null
                ? l10n.cherryUnitShort
                : l10n.cherryUnit(
                    KFormat.bidiIsolate(KFormat.grouped(payout.rateCherries)),
                    KFormat.bidiIsolate(
                      formatPrice(payout.rateMinor, payout.currency),
                    ),
                    KFormat.bidiIsolate(
                      formatPrice(payout.minAmountMinor, payout.currency),
                    ),
                  ),
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.md),
          if (pending != null) ...[
            _PendingNote(
              key: pendingKey,
              withdrawal: pending,
              days: payout?.payoutDays ?? 0,
            ),
            const SizedBox(height: KSpacing.md),
          ],
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
            // Always offered: the sheet says what stops a request (the
            // minimum, a request already waiting) instead of a dead button.
            available: true,
            reason: '',
            onPressed: wallet == null
                ? null
                : () => unawaited(showCherryWithdrawSheet(context, wallet)),
          ),
        ],
      ),
      if (requests.isNotEmpty) ...[
        const SizedBox(height: KSpacing.md),
        WalletSection(
          title: l10n.cherryWithdrawalsTitle,
          children: [
            for (final r in requests)
              _WithdrawalTile(withdrawal: r, localeTag: localeTag),
          ],
        ),
      ],
      const SizedBox(height: KSpacing.md),
      WalletSectionPiece(title: l10n.cherryHistoryTitle),
      for (final row in rows) WalletSectionPiece(child: row),
      const WalletSectionPiece(bottom: true, child: SizedBox.shrink()),
    ];
  }
}

/// The waiting request, said plainly: paid by hand within N days.
class _PendingNote extends StatelessWidget {
  const new({required this.withdrawal, required this.days, super.key});

  final CherryWithdrawal withdrawal;
  final int days;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_rounded, size: 20, color: p.warning),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.cherryPendingNote(
                  KFormat.bidiIsolate(
                    formatPrice(withdrawal.amountMinor, withdrawal.currency),
                  ),
                  days,
                ),
                style: t.label.copyWith(color: p.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const new({required this.withdrawal, required this.localeTag});

  final CherryWithdrawal withdrawal;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final w = withdrawal;
    final (status, color) = switch (w.status) {
      CherryWithdrawalStatus.pending => (
        l10n.cherryWithdrawalPending,
        p.warning,
      ),
      CherryWithdrawalStatus.paid => (l10n.cherryWithdrawalPaid, p.success),
      CherryWithdrawalStatus.rejected => (
        l10n.cherryWithdrawalRejected,
        p.error,
      ),
    };
    final amount = formatPrice(w.amountMinor, w.currency);
    final line = l10n.cherryWithdrawalLine(
      KFormat.bidiIsolate(KFormat.grouped(w.cherries)),
    );
    final when = KFormat.date(w.createdAt, localeTag);
    final note = w.decisionNote;
    return Semantics(
      key: WalletCherryTab.withdrawalKey(w.id),
      container: true,
      label: [amount, line, status, when, ?note].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amount,
                    textDirection: TextDirection.ltr,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    '$line · $when',
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                  if (note != null)
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: p.textTertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.sm,
                  vertical: KSpacing.xxs,
                ),
                child: Text(
                  status,
                  style: t.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CherryTile extends StatelessWidget {
  const new({required this.entry, required this.localeTag});

  final CherryLedgerEntry entry;
  final String localeTag;

  static String reasonLabel(AppLocalizations l10n, CherryLedgerReason r) =>
      switch (r) {
        CherryLedgerReason.giftReceived => l10n.cherryReasonGift,
        CherryLedgerReason.agencyCommission => l10n.cherryReasonAgency,
        CherryLedgerReason.parentCommission => l10n.cherryReasonParent,
        CherryLedgerReason.giftReversal => l10n.cherryReasonGiftReversal,
        CherryLedgerReason.agencyCommissionReversal ||
        CherryLedgerReason.parentCommissionReversal =>
          l10n.cherryReasonCommissionReversal,
        CherryLedgerReason.withdrawalHold => l10n.cherryReasonWithdrawal,
        CherryLedgerReason.withdrawalRefund => l10n.cherryReasonRefund,
        CherryLedgerReason.taskReward => l10n.cherryReasonTask,
        CherryLedgerReason.other => l10n.cherryReasonOther,
      };

  static IconData iconOf(CherryLedgerReason r) => switch (r) {
    CherryLedgerReason.giftReceived ||
    CherryLedgerReason.giftReversal => Icons.card_giftcard_rounded,
    CherryLedgerReason.agencyCommission ||
    CherryLedgerReason.parentCommission ||
    CherryLedgerReason.agencyCommissionReversal ||
    CherryLedgerReason.parentCommissionReversal => Icons.groups_rounded,
    CherryLedgerReason.withdrawalHold ||
    CherryLedgerReason.withdrawalRefund => Icons.account_balance_rounded,
    CherryLedgerReason.taskReward => Icons.task_alt_rounded,
    CherryLedgerReason.other => Icons.swap_vert_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final e = entry;
    final gift = e.gift;
    final title = gift == null
        ? reasonLabel(l10n, e.reason)
        : l10n.earnGiftLine(KFormat.bidiIsolate(gift.giftName), gift.quantity);
    final sender = gift?.sender;
    final from = gift == null
        ? null
        : sender == null
        ? l10n.earnFromHidden
        : l10n.earnFrom(
            KFormat.bidiIsolate(
              sender.displayName.isEmpty ? sender.username : sender.displayName,
            ),
          );
    final where = gift == null
        ? null
        : gift.context == EarningContext.dm
        ? l10n.earnContextDm
        : l10n.earnContextLive;
    final subtitle = gift == null
        ? null
        : e.reason == CherryLedgerReason.giftReversal
        ? '${l10n.cherryReasonGiftReversal} · $from'
        : '$from · $where';
    final when =
        '${KFormat.date(e.createdAt, localeTag)} · '
        '${KFormat.time(e.createdAt, localeTag)}';
    final amount = signedCherries(e.delta);
    final share = gift == null
        ? null
        : l10n.earnShare(
            sharePercent(gift.shareBps),
            KFormat.grouped(gift.giftCoins),
          );
    return Semantics(
      key: WalletCherryTab.entryKey(e.id),
      container: true,
      label: [
        title,
        ?subtitle,
        when,
        l10n.walletCherries(amount),
        ?share,
      ].join(', '),
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
                child: Icon(iconOf(e.reason), size: 18, color: p.primary),
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
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
                      Flexible(
                        child: Text(
                          amount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: t.bodyStrong.copyWith(
                            color: e.delta > 0 ? p.success : p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xxs),
                      const KCherryIcon(size: 16),
                    ],
                  ),
                  if (share != null)
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
