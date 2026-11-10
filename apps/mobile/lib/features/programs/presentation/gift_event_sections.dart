import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_page_theme.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

/// v1.97-social (D303): a board kind's tab label.
String eventBoardLabel(AppLocalizations l10n, EventBoardKind kind) =>
    switch (kind) {
      EventBoardKind.senders => l10n.eventsBoardSenders,
      EventBoardKind.receivers => l10n.eventsBoardReceivers,
      EventBoardKind.creators => l10n.eventsBoardCreators,
      EventBoardKind.agencies => l10n.eventsBoardAgencies,
      EventBoardKind.cp => l10n.eventsBoardCp,
    };

/// v1.105-social (D340, §10.134.1): the event is over for this board — the
/// event ended (the server's status), or the board shown is final. Then the
/// page shows the result, never the points still missing.
bool eventBoardEnded(EventSummary event, EventLeaderboard? board) =>
    event.status == EventStatus.ended || (board?.isFinal ?? false);

/// One prize item as words (coins are drawn with the coin by
/// [EventPrizeChips]; this is their spoken form too).
String eventPrizeText(AppLocalizations l10n, EventPrizeItem item) =>
    switch (item.type) {
      'COINS' => l10n.meHubCoins(KFormat.grouped(item.amount ?? 0)),
      'CHERRIES' => l10n.eventsPrizeCherries(KFormat.grouped(item.amount ?? 0)),
      // D303 follow-ups: the couple's two amounts (by each partner's role).
      'CP_MONEY' => l10n.eventsPrizeCpMoney(
        KFormat.grouped(item.cherries ?? 0),
        KFormat.grouped(item.coins ?? 0),
      ),
      'VIP' => l10n.eventsPrizeDays(
        item.name ?? l10n.eventsPrizeVip,
        '${item.days ?? 0}',
      ),
      _ when item.isPermanent => l10n.eventsPrizePermanent(
        _itemName(l10n, item),
      ),
      _ => l10n.eventsPrizeDays(_itemName(l10n, item), '${item.days ?? 0}'),
    };

String _itemName(AppLocalizations l10n, EventPrizeItem item) {
  final name = item.name ?? l10n.eventsPrizeItem;
  final level = item.level;
  return item.type == 'BADGE' && level != null
      ? l10n.eventsPrizeMedalLevel(name, '$level')
      : name;
}

/// A prize bundle as chips: coins with the Kabso coin, the rest as words.
class EventPrizeChips extends StatelessWidget {
  const new(this.items, {super.key, this.tappable = false});

  final List<EventPrizeItem> items;

  /// D303 follow-up: a tap previews the prize.
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final gold = programGold(context);
    return Semantics(
      label: [for (final i in items) eventPrizeText(l10n, i)].join('، '),
      excludeSemantics: true,
      child: Wrap(
        spacing: KSpacing.xs,
        runSpacing: KSpacing.xxs,
        children: [
          for (final i in items)
            GestureDetector(
              onTap: tappable ? () => showEventPrizeSheet(context, i) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color:
                      EventPageTheme.of(context)?.chipFill ??
                      Color.alphaBlend(gold.withValues(alpha: 0.14), p.surface),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: i.type == 'COINS'
                    ? CoinAmount(
                        i.amount ?? 0,
                        size: 12,
                        style: t.caption.copyWith(color: p.textPrimary),
                      )
                    : Text(
                        eventPrizeText(l10n, i),
                        style: t.caption.copyWith(color: p.textPrimary),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «هدايا الفعالية»: each event gift with its picture, price and the points
/// one gift earns (per recipient).
class EventGiftsSection extends ConsumerWidget {
  const new({required this.gifts, super.key});

  final List<EventGiftInfo> gifts;

  static const sectionKey = Key('event.gifts');
  static Key giftKey(String code) => Key('event.gift.$code');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return ProgramSection(
      key: sectionKey,
      title: l10n.eventsGifts,
      subtitle: l10n.eventsGiftPointsHint,
      child: LayoutBuilder(
        builder: (context, box) {
          // Four to a row as in the reference; fewer on a narrow screen.
          final columns = box.maxWidth >= 320 ? 4 : 3;
          final width = (box.maxWidth - KSpacing.sm * (columns - 1)) / columns;
          return Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final g in gifts)
                GestureDetector(
                  onTap: () => showEventGiftSheet(context, ref, g),
                  child: Semantics(
                    key: giftKey(g.code),
                    button: true,
                    label: [
                      g.name,
                      l10n.meHubCoins(KFormat.grouped(g.priceCoins)),
                      l10n.eventsGiftPoints(KFormat.grouped(g.pointsEach)),
                    ].join('، '),
                    excludeSemantics: true,
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.symmetric(
                        vertical: KSpacing.sm,
                        horizontal: KSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceRaised,
                        borderRadius: BorderRadius.circular(KRadius.md),
                        border: EventPageTheme.of(context)?.tileBorder == null
                            ? null
                            : Border.all(
                                color: EventPageTheme.of(context)!.tileBorder!,
                              ),
                      ),
                      child: Column(
                        children: [
                          KGiftImage(
                            g.assetKey,
                            imageUrl: g.imageUrl,
                            size: 44,
                          ),
                          const SizedBox(height: KSpacing.xxs),
                          Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(color: p.textPrimary),
                          ),
                          CoinAmount(
                            g.priceCoins,
                            size: 12,
                            style: t.caption.copyWith(color: p.textSecondary),
                          ),
                          Text(
                            l10n.eventsGiftPoints(
                              KFormat.grouped(g.pointsEach),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              color: programGold(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The gift event's rules: the team's text, then the three rules every
/// gift event has (owner's reference).
class GiftEventRules extends StatelessWidget {
  const new({required this.rules, super.key, this.hasMinimum = true});

  final String rules;

  /// D340: no rule about the minimum when no board has one.
  final bool hasMinimum;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final lines = [
      if (rules.trim().isNotEmpty) rules.trim(),
      l10n.eventsRuleOnlyGifts,
      if (hasMinimum) l10n.eventsRuleMinimum,
      l10n.eventsRuleAutoPayout,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.xs),
            child: Text(
              '${i + 1}. ${lines[i]}',
              style: t.body.copyWith(color: p.textPrimary),
            ),
          ),
      ],
    );
  }
}

/// «الترتيب والجوائز»: a tab per board the event has (SENDERS, RECEIVERS,
/// CREATORS, AGENCIES, CP), the selected board's prize table and minimum,
/// the caller's place (and the points still missing), and the top 100 —
/// live until the event is frozen.
class GiftEventBoards extends ConsumerStatefulWidget {
  const new({required this.event, super.key});

  final EventDetail event;

  static const sectionKey = Key('event.boards');
  static const prizeTableKey = Key('event.boards.prizes');
  static const meKey = Key('event.boards.me');
  static Key tabKey(EventBoardKind kind) =>
      Key('event.boards.tab.${kind.wire}');
  static Key rowKey(int rank) => Key('event.boards.rank.$rank');

  /// D303 follow-ups: the selected tab of an event's page (shared with the
  /// sticky «مركزي» bar).
  static ValueNotifier<int> selection(String eventId) =>
      _selection.putIfAbsent(eventId, () => ValueNotifier(0));
  static final _selection = <String, ValueNotifier<int>>{};

  /// How often a shown, running board reloads.
  static const refreshEvery = Duration(seconds: 30);

  @override
  ConsumerState<GiftEventBoards> createState() => _GiftEventBoardsState();
}

class _GiftEventBoardsState extends ConsumerState<GiftEventBoards> {
  Timer? _refresh;

  int get _selected => GiftEventBoards.selection(widget.event.id).value;
  set _selected(int value) =>
      GiftEventBoards.selection(widget.event.id).value = value;

  @override
  void initState() {
    super.initState();
    // D303 follow-up: the live board reloads while shown (not when frozen,
    // not while the page is hidden).
    if (widget.event.status == EventStatus.running) {
      _refresh = Timer.periodic(GiftEventBoards.refreshEvery, (_) {
        if (!mounted || !TickerMode.valuesOf(context).enabled) return;
        final boards = widget.event.boards;
        if (boards.isEmpty) return;
        final kind = boards[_selected.clamp(0, boards.length - 1)].kind;
        ref.invalidate(eventBoardProvider((id: widget.event.id, board: kind)));
      });
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    // The page is gone: its tab choice goes with it.
    GiftEventBoards._selection.remove(widget.event.id)?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final boards = widget.event.boards;
    if (boards.isEmpty) return const SizedBox.shrink();
    final index = _selected.clamp(0, boards.length - 1);
    final board = boards[index];
    final key = (id: widget.event.id, board: board.kind);
    final live = ref.watch(eventBoardProvider(key));
    final ended = eventBoardEnded(widget.event, live.value);
    return ProgramSection(
      key: GiftEventBoards.sectionKey,
      title: l10n.eventsBoardsTitle,
      // D340: after the end the results; a board without a minimum says none.
      subtitle: ended
          ? (live.value?.isFinal ?? false)
                ? l10n.eventsBoardFinal
                : l10n.eventsResultsPending
          : board.minPoints > 0
          ? l10n.eventsMinPoints(KFormat.grouped(board.minPoints))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (boards.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < boards.length; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: KSpacing.xs,
                      ),
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        child: InkWell(
                          key: GiftEventBoards.tabKey(boards[i].kind),
                          borderRadius: BorderRadius.circular(KRadius.pill),
                          onTap: () => setState(() => _selected = i),
                          child: EventPageTheme.of(context) != null
                              ? _ThemedTab(
                                  label: eventBoardLabel(l10n, boards[i].kind),
                                  selected: i == index,
                                )
                              : Container(
                                  constraints: const BoxConstraints(
                                    minHeight: KSizes.minTouchTarget,
                                  ),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KSpacing.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == index
                                        ? p.primary
                                        : p.surfaceRaised,
                                    borderRadius: BorderRadius.circular(
                                      KRadius.pill,
                                    ),
                                  ),
                                  child: Text(
                                    eventBoardLabel(l10n, boards[i].kind),
                                    style: t.label.copyWith(
                                      color: i == index
                                          ? p.onPrimary
                                          : p.textPrimary,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: KSpacing.sm),
          Column(
            key: GiftEventBoards.prizeTableKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in board.prizes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          line.rankFrom == line.rankTo
                              ? l10n.eventsRank('${line.rankFrom}')
                              : l10n.eventsRanks(
                                  '${line.rankFrom}',
                                  '${line.rankTo}',
                                ),
                          style: t.bodyStrong.copyWith(color: p.textPrimary),
                        ),
                      ),
                      Expanded(
                        child: EventPrizeChips(line.items, tappable: true),
                      ),
                    ],
                  ),
                ),
              if (board.prizes.isEmpty)
                Text(
                  l10n.eventsNoPrizes,
                  style: t.body.copyWith(color: p.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          switch (live) {
            AsyncValue(value: final b?) => _BoardRows(board: b, ended: ended),
            AsyncValue(:final error?, isLoading: false) => FailureErrorState(
              title: l10n.eventsLoadError,
              failure: toAppFailure(error),
              onRetry: () => ref.invalidate(eventBoardProvider(key)),
              compact: true,
            ),
            _ => const Padding(
              padding: EdgeInsets.all(KSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}

class _BoardRows extends StatelessWidget {
  const new({required this.board, required this.ended});

  final EventLeaderboard board;

  /// D340: the event is over — the caller's result instead of what is
  /// missing.
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rank = board.myRank;
    final mine = ended
        ? rank == null
              ? l10n.eventsNotParticipated
              : l10n.eventsFinalRank('$rank')
        : rank == null
        ? l10n.eventsMeNotRanked
        : l10n.eventsMeRank('$rank');
    final won = ended && board.myQualified && board.myBundle.isNotEmpty;
    // D340: no «باقي N نقطة للتأهل» once ended, nor on a board without a
    // minimum (nothing is missing there); «لم تتأهل» after the end.
    final status = ended
        ? rank == null
              ? null
              : won
              ? l10n.eventsYouWon
              : board.myQualified
              ? null
              : l10n.eventsNotQualifiedFinal(KFormat.grouped(board.minPoints))
        : board.myQualified
        ? l10n.eventsQualified
        : board.minPoints > 0
        ? l10n.eventsPointsToQualify(KFormat.grouped(board.pointsToQualify))
        : null;
    final gold = board.myQualified && (won || !ended);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: GiftEventBoards.meKey,
          padding: const EdgeInsets.all(KSpacing.sm),
          decoration: BoxDecoration(
            color:
                EventPageTheme.of(context)?.meFill ??
                Color.alphaBlend(p.primary.withValues(alpha: 0.10), p.surface),
            borderRadius: BorderRadius.circular(KRadius.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mine,
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                  ),
                  // D340: no «0» beside «not on the board».
                  if (rank != null)
                    Text(
                      KFormat.grouped(board.myScore),
                      textDirection: TextDirection.ltr,
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                ],
              ),
              if (status != null) ...[
                const SizedBox(height: KSpacing.xxs),
                Text(
                  status,
                  style: t.caption.copyWith(
                    color: gold ? programGold(context) : p.textSecondary,
                  ),
                ),
              ],
              if (board.myBundle.isNotEmpty && (!ended || won)) ...[
                const SizedBox(height: KSpacing.xxs),
                EventPrizeChips(board.myBundle),
              ],
              if (won && board.myPrizeStatus == EventPrizeStatus.pending) ...[
                const SizedBox(height: KSpacing.xxs),
                Text(
                  l10n.eventsPrizePending,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        if (board.giftRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
            child: Text(
              l10n.eventsBoardEmpty,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.textSecondary),
            ),
          )
        else
          for (final r in board.giftRows) _GiftRankRow(row: r),
      ],
    );
  }
}

String _nameOf(UserSummary u) =>
    u.displayName.isEmpty ? u.username : u.displayName;

class _GiftRankRow extends StatelessWidget {
  const new({required this.row});

  final GiftBoardRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final partner = row.partner;
    final owner = _nameOf(row.user);
    final title = row.isAgency
        ? (row.agencyName ?? owner)
        : partner != null
        ? l10n.eventsCpPair(owner, _nameOf(partner))
        : owner;
    final subtitle = row.isAgency ? l10n.eventsAgencyOwner(owner) : null;
    final medal = switch (row.rank) {
      1 => KBrandColors.gold,
      2 => const Color(0xFFB4B4BE),
      3 => const Color(0xFFC07A42),
      _ => null,
    };
    return Semantics(
      key: GiftEventBoards.rowKey(row.rank),
      label: [
        l10n.eventsRank('${row.rank}'),
        title,
        ?subtitle,
        KFormat.grouped(row.score),
        if (!row.qualified) l10n.eventsNotQualified,
        for (final i in row.prize) eventPrizeText(l10n, i),
      ].join('، '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // D303 follow-up: Kabso's own crown on the first three.
                  if (row.rank <= 3) RankCrown(rank: row.rank, size: 18),
                  Text(
                    '${row.rank}',
                    textAlign: TextAlign.center,
                    style: t.bodyStrong.copyWith(
                      color: medal ?? p.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            KAvatar(
              name: owner,
              imageUrl: row.user.avatarUrl,
              size: KSizes.avatarSm,
            ),
            if (partner != null) ...[
              const SizedBox(width: 2),
              KAvatar(
                name: _nameOf(partner),
                imageUrl: partner.avatarUrl,
                size: KSizes.avatarSm,
              ),
            ],
            const SizedBox(width: KSpacing.sm),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  if (row.prize.isNotEmpty) EventPrizeChips(row.prize),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  KFormat.grouped(row.score),
                  textDirection: TextDirection.ltr,
                  style: t.label.copyWith(color: p.textPrimary),
                ),
                if (!row.qualified)
                  Text(
                    l10n.eventsNotQualified,
                    style: t.caption.copyWith(color: p.textTertiary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// D303 follow-ups (owner: «يجب ان تكون الصفحة تفاعلية ويمكن ان تحتوي انميشن او
// حركات»): the event's own art behind the page, gold-framed cards, crowns for
// the first three, a live countdown, the board refreshing while shown, a
// sticky «مركزي» bar, and taps on gifts and prizes.

/// The gold of the event page's frames and headings.
const Color kEventGold = kProgramFrameGold;

/// The event's background (its still: a picture, an animated picture's
/// first frame is the picture itself, a video's poster), darkened for
/// legibility, with the title art on top and the Lottie overlay playing over
/// the page — paused with reduced motion and when the page is hidden.
class GiftEventBackdrop extends StatelessWidget {
  const new({required this.art, super.key});

  final EventArt art;

  static const overlayKey = Key('event.art.overlay');
  static const backgroundKey = Key('event.art.background');

  /// Tests and goldens: loads the art from elsewhere than the network.
  @visibleForTesting
  static ImageProvider Function(String url)? imageForTesting;

  static ImageProvider image(String url) =>
      imageForTesting?.call(url) ?? NetworkImage(url);

  @override
  Widget build(BuildContext context) {
    final still = art.stillUrl;
    final motion =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    final overlay = art.overlayUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (still != null)
          Image(
            key: backgroundKey,
            image: image(
              // An animated picture plays unless motion is reduced (then
              // the poster when there is one).
              motion || art.posterUrl == null ? still : art.posterUrl!,
            ),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF1A1208)),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors:
                  EventPageTheme.of(context)?.scrim ??
                  const [
                    Color(0x33000000),
                    Color(0x99000000),
                    Color(0xCC000000),
                  ],
            ),
          ),
        ),
        if (overlay != null && art.overlayFormat == 'LOTTIE' && motion)
          IgnorePointer(
            key: overlayKey,
            child: Lottie.network(overlay, repeat: true, fit: BoxFit.cover),
          ),
      ],
    );
  }
}

/// Kabso's own crown (a simple drawing, no third-party art) for ranks 1–3.
class RankCrown extends StatelessWidget {
  const new({required this.rank, this.size = 22, super.key});

  final int rank;
  final double size;

  static Color colorOf(int rank) => switch (rank) {
    1 => const Color(0xFFF5C542),
    2 => const Color(0xFFC9CCD6),
    _ => const Color(0xFFD08A4E),
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 0.8,
    child: CustomPaint(painter: _CrownPainter(colorOf(rank))),
  );
}

class _CrownPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.35)
      ..lineTo(w * 0.27, h * 0.6)
      ..lineTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.73, h * 0.6)
      ..lineTo(w, h * 0.35)
      ..lineTo(w * 0.88, h)
      ..lineTo(w * 0.12, h)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0x66000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    final dot = Paint()..color = const Color(0xFFFFFFFF);
    for (final x in [0.0, 0.5, 1.0]) {
      canvas.drawCircle(
        Offset(w * x, x == 0.5 ? h * 0.1 : h * 0.35),
        w * 0.07,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.color != color;
}

/// «تبدأ بعد / تنتهي بعد …»: a countdown that ticks every second while shown.
class EventCountdown extends StatefulWidget {
  const new({
    required this.event,
    this.now,
    super.key,
    this.style = EventCountdownStyle.pill,
  });

  final EventSummary event;

  /// KL-352 prototype: the banner style.
  final EventCountdownStyle style;

  /// Tests and goldens: a fixed clock.
  final DateTime Function()? now;

  static const countdownKey = Key('event.countdown');

  @override
  State<EventCountdown> createState() => _EventCountdownState();
}

class _EventCountdownState extends State<EventCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && TickerMode.valuesOf(context).enabled) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _span(Duration d) {
    final days = d.inDays;
    final h = (d.inHours % 24).toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return days > 0 ? '${days}d $h:$m:$s' : '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = (widget.now ?? DateTime.now)();
    final e = widget.event;
    final end = e.endsAt;
    final text = now.isBefore(e.startsAt)
        ? l10n.eventsCountdownStarts(_span(e.startsAt.difference(now)))
        : end != null && now.isBefore(end)
        ? l10n.eventsCountdownEnds(_span(end.difference(now)))
        : l10n.eventsCountdownEnded;
    if (widget.style != EventCountdownStyle.pill) {
      final starts = now.isBefore(e.startsAt);
      final left = starts
          ? e.startsAt.difference(now)
          : end != null && now.isBefore(end)
          ? end.difference(now)
          : null;
      String two(int v) => v.toString().padLeft(2, '0');
      return KeyedSubtree(
        key: EventCountdown.countdownKey,
        child: EventCountdownBanner(
          style: widget.style,
          fallback: text,
          parts: left == null
              ? null
              : (
                  label:
                      (starts
                              ? l10n.eventsCountdownStarts('')
                              : l10n.eventsCountdownEnds(''))
                          .trim(),
                  days: left.inDays,
                  h: two(left.inHours % 24),
                  m: two(left.inMinutes % 60),
                  s: two(left.inSeconds % 60),
                ),
        ),
      );
    }
    final et = EventPageTheme.of(context);
    final label = Text(
      text,
      textAlign: TextAlign.center,
      style: context.textStyles.label.copyWith(
        color: et?.countdownText ?? kEventGold,
        fontWeight: et == null ? null : FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (et != null) {
      return EventFrame(
        key: EventCountdown.countdownKey,
        fill: et.countdownFill,
        border: et.countdownBorder,
        borderWidth: et.cardBorderWidth.clamp(1, 1.6),
        radius: 999,
        blur: et.blur,
        glow: et.glow,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.xs + 2,
        ),
        child: label,
      );
    }
    return Container(
      key: EventCountdown.countdownKey,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xA6140C04),
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(color: kEventGold),
      ),
      child: label,
    );
  }
}

/// The sticky «مركزي» bar: the caller's place and points on the selected
/// board, and what is missing — to the next rank, or to the minimum.
class GiftEventMyBar extends ConsumerWidget {
  const new({required this.event, super.key});

  final EventDetail event;

  static const barKey = Key('event.myBar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final boards = event.boards;
    if (boards.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: GiftEventBoards.selection(event.id),
      builder: (context, selected, _) {
        final kind = boards[selected.clamp(0, boards.length - 1)].kind;
        final b = ref
            .watch(eventBoardProvider((id: event.id, board: kind)))
            .value;
        if (b == null) return const SizedBox.shrink();
        final rank = b.myRank;
        final ended = eventBoardEnded(event, b);
        final above = rank == null || rank <= 1
            ? null
            : b.giftRows.where((r) => r.rank == rank - 1).firstOrNull;
        final String? hint;
        final String label;
        if (ended) {
          // D340 (§10.134.1): the final result, never what is missing.
          label = rank == null
              ? l10n.eventsNotParticipated
              : l10n.eventsMyBarFinal('$rank', KFormat.grouped(b.myScore));
          final first = b.myBundle.firstOrNull;
          hint = rank == null
              ? null
              : !b.myQualified
              ? l10n.eventsNotQualifiedYou
              : first == null
              ? null
              : b.myBundle.length == 1
              ? l10n.eventsYouWonShort(eventPrizeText(l10n, first))
              : l10n.eventsYouWonMore(
                  eventPrizeText(l10n, first),
                  '${b.myBundle.length - 1}',
                );
        } else {
          label = rank == null
              ? l10n.eventsMyBarNotRanked
              : l10n.eventsMyBar('$rank', KFormat.grouped(b.myScore));
          // D340: a board without a minimum has nothing «to qualify».
          hint = !b.myQualified
              ? b.minPoints > 0
                    ? l10n.eventsPointsToQualify(
                        KFormat.grouped(b.pointsToQualify),
                      )
                    : null
              : above != null
              ? l10n.eventsToNextRank(
                  KFormat.grouped(above.score - b.myScore + 1),
                  '${above.rank}',
                )
              : l10n.eventsQualified;
        }
        final et = EventPageTheme.of(context);
        if (et != null) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.md,
                0,
                KSpacing.md,
                KSpacing.sm,
              ),
              child: EventFrame(
                key: barKey,
                fill: et.barFill,
                border: et.barBorder,
                borderWidth: et.cardBorderWidth,
                radius: et.radius,
                blur: et.blur,
                glow: et.glow,
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                  vertical: KSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: context.textStyles.bodyStrong.copyWith(
                          color: et.barText,
                        ),
                      ),
                    ),
                    if (hint != null)
                      Flexible(
                        child: Text(
                          hint,
                          textAlign: TextAlign.end,
                          style: context.textStyles.caption.copyWith(
                            color: et.barHint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
        return SafeArea(
          top: false,
          child: Container(
            key: barKey,
            margin: const EdgeInsets.fromLTRB(
              KSpacing.md,
              0,
              KSpacing.md,
              KSpacing.sm,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: const Color(0xF0140C04),
              borderRadius: BorderRadius.circular(KRadius.lg),
              border: Border.all(color: kEventGold),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.textStyles.bodyStrong.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                if (hint != null)
                  Flexible(
                    child: Text(
                      hint,
                      textAlign: TextAlign.end,
                      style: context.textStyles.caption.copyWith(
                        color: kEventGold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A tap on an event gift: gifts are sent from a live's gift panel — this
/// explains it and offers the lives (the event page is not inside a live).
Future<void> showEventGiftSheet(
  BuildContext context,
  WidgetRef ref,
  EventGiftInfo gift,
) => showModalBottomSheet<void>(
  context: context,
  builder: (sheet) {
    final l10n = sheet.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KGiftImage(gift.assetKey, imageUrl: gift.imageUrl, size: 64),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.eventsSendGiftTitle(gift.name),
              style: sheet.textStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.eventsSendGiftBody,
              textAlign: TextAlign.center,
              style: sheet.textStyles.body,
            ),
            const SizedBox(height: KSpacing.md),
            KButton(
              label: l10n.eventsGoLive,
              onPressed: () {
                Navigator.of(sheet).pop();
                openLiveHub(context, ref, FeedTab.popular);
              },
            ),
          ],
        ),
      ),
    );
  },
);

/// A tap on a prize: what it is, for how long (or «دائم»), with its art when
/// the server sends one (a medal level's picture).
Future<void> showEventPrizeSheet(BuildContext context, EventPrizeItem item) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) {
        final l10n = sheet.l10n;
        final image = item.imageUrl;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.eventsPrizePreview, style: sheet.textStyles.title),
                const SizedBox(height: KSpacing.md),
                if (image != null)
                  Image(
                    image: GiftEventBackdrop.image(image),
                    width: 128,
                    height: 128,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  eventPrizeText(l10n, item),
                  textAlign: TextAlign.center,
                  style: sheet.textStyles.bodyStrong,
                ),
              ],
            ),
          ),
        );
      },
    );

/// KL-352 prototype: a board tab drawn with the event page theme.
class _ThemedTab extends StatelessWidget {
  const _ThemedTab({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final et = EventPageTheme.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
      child: EventFrame(
        fill: selected ? et.tabSelectedFill : et.tabFill,
        border: selected ? et.tabSelectedBorder : et.tabBorder,
        borderWidth: et.cardBorderWidth.clamp(1, 1.6),
        radius: 999,
        glow: selected ? et.glow : const [],
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: 12,
        ),
        child: Text(
          label,
          style: context.textStyles.label.copyWith(
            color: selected ? et.tabSelectedText : et.tabText,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
