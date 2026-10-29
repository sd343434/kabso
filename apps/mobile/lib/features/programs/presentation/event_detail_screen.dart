import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_center_screen.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What an event's score counts, for the leaderboard header.
String eventMetricLabel(AppLocalizations l10n, String metric) =>
    switch (metric) {
      'GIFT_COINS_RECEIVED' => l10n.eventsMetricGiftsReceived,
      'GIFT_COINS_SENT' => l10n.eventsMetricGiftsSent,
      'LIVE_MINUTES' => l10n.eventsMetricLiveMinutes,
      'TAPS_RECEIVED' => l10n.eventsMetricTaps,
      'NEW_FOLLOWERS' => l10n.eventsMetricFollowers,
      _ => l10n.eventsMetricOther,
    };

/// `/events/:eventId` (D166): one event — banner, dates, rules, prizes and
/// the leaderboard (top 100 and the caller's own place), live until the
/// event is frozen, then the final results.
class EventDetailScreen extends ConsumerWidget {
  const new({required this.eventId, super.key});

  final String eventId;

  static const rulesKey = Key('event.rules');
  static const prizesKey = Key('event.prizes');
  static const boardKey = Key('event.board');
  static const meKey = Key('event.me');

  static Key rankKey(int rank) => Key('event.rank.$rank');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final detail = ref.watch(eventDetailProvider(eventId));
    final board = ref.watch(eventLeaderboardProvider(eventId));
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    Future<void> refresh() async {
      ref
        ..invalidate(eventDetailProvider(eventId))
        ..invalidate(eventLeaderboardProvider(eventId));
      try {
        await ref.read(eventDetailProvider(eventId).future);
      } on Object {
        // The page shows the failure with a retry.
      }
    }

    final List<Widget> children = switch (detail) {
      AsyncValue(value: final e?) => [
        ClipRRect(
          borderRadius: BorderRadius.circular(KRadius.lg),
          child: EventBanner(
            event: e,
            hue: ProgramHues.of(e.id),
            height: 140,
          ),
        ),
        const SizedBox(height: KSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                e.title,
                style: t.headline.copyWith(color: p.textPrimary),
              ),
            ),
            EventStatusTag(event: e),
          ],
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          eventDates(l10n, e, localeTag),
          style: t.body.copyWith(color: p.textSecondary),
        ),
        if (e.forHosts)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xs),
            child: Text(
              l10n.eventsForHosts,
              style: t.caption.copyWith(color: p.textTertiary),
            ),
          ),
        const SizedBox(height: KSpacing.lg),
        ProgramSection(
          key: rulesKey,
          title: l10n.eventsRules,
          child: Text(
            e.rules.isEmpty ? l10n.eventsNoRules : e.rules,
            style: t.body.copyWith(color: p.textPrimary),
          ),
        ),
        ProgramSection(
          key: prizesKey,
          title: l10n.eventsPrizes,
          subtitle: e.paidAt != null
              ? l10n.eventsPrizesPaid
              : (e.prizes.isEmpty ? null : l10n.eventsPrizesReview),
          child: e.prizes.isEmpty
              ? Text(
                  l10n.eventsNoPrizes,
                  style: t.body.copyWith(color: p.textSecondary),
                )
              : Column(
                  children: [
                    for (final prize in e.prizes)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: KSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                prize.rankFrom == prize.rankTo
                                    ? l10n.eventsRank('${prize.rankFrom}')
                                    : l10n.eventsRanks(
                                        '${prize.rankFrom}',
                                        '${prize.rankTo}',
                                      ),
                                style: t.bodyStrong.copyWith(
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                            CoinAmount(prize.coins),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        _Board(
          metric: eventMetricLabel(l10n, e.metric),
          board: board,
          onRetry: () => ref.invalidate(eventLeaderboardProvider(eventId)),
        ),
      ],
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.eventsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
          compact: true,
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(KSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };

    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.eventsDetailTitle),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xl,
          ),
          children: children,
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const new({
    required this.metric,
    required this.board,
    required this.onRetry,
  });

  final String metric;
  final AsyncValue<EventLeaderboard> board;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final Widget child = switch (board) {
      AsyncValue(value: final b?) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: EventDetailScreen.meKey,
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                p.primary.withValues(alpha: 0.10),
                p.surface,
              ),
              borderRadius: BorderRadius.circular(KRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    b.myRank == null
                        ? l10n.eventsMeNotRanked
                        : l10n.eventsMeRank('${b.myRank}'),
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                ),
                Text(
                  KFormat.grouped(b.myScore),
                  textDirection: TextDirection.ltr,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          if (b.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
              child: Text(
                l10n.eventsBoardEmpty,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: p.textSecondary),
              ),
            )
          else
            for (final r in b.rows) _RankRow(row: r),
        ],
      ),
      AsyncValue(:final error?, isLoading: false) => FailureErrorState(
        title: l10n.eventsLoadError,
        failure: toAppFailure(error),
        onRetry: onRetry,
        compact: true,
      ),
      _ => const Padding(
        padding: EdgeInsets.all(KSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
    final isFinal = board.value?.isFinal ?? false;
    return ProgramSection(
      key: EventDetailScreen.boardKey,
      title: l10n.eventsBoard,
      subtitle: '${isFinal ? l10n.eventsBoardFinal : l10n.eventsBoardLive}'
          ' · $metric',
      child: child,
    );
  }
}

class _RankRow extends StatelessWidget {
  const new({required this.row});

  final EventRank row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final name = row.user.displayName.isEmpty
        ? row.user.username
        : row.user.displayName;
    final medal = switch (row.rank) {
      1 => KBrandColors.gold,
      2 => const Color(0xFFB4B4BE),
      3 => const Color(0xFFC07A42),
      _ => null,
    };
    return Semantics(
      key: EventDetailScreen.rankKey(row.rank),
      label: [
        l10n.eventsRank('${row.rank}'),
        name,
        KFormat.grouped(row.score),
        if (row.prizeCoins > 0) l10n.meHubCoins(KFormat.grouped(row.prizeCoins)),
      ].join('، '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${row.rank}',
                textAlign: TextAlign.center,
                style: t.bodyStrong.copyWith(
                  color: medal ?? p.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            KAvatar(
              name: name,
              imageUrl: row.user.avatarUrl,
              size: KSizes.avatarSm,
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  KFormat.grouped(row.score),
                  textDirection: TextDirection.ltr,
                  style: t.label.copyWith(color: p.textPrimary),
                ),
                if (row.prizeCoins > 0)
                  CoinAmount(
                    row.prizeCoins,
                    size: 12,
                    style: t.caption.copyWith(color: programGold(context)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
