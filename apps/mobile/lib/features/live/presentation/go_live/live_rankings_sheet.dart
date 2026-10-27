import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Keys of the rankings sheet (tests and captures).
abstract final class LiveRankingsKeys {
  static const sheet = Key('rankings.sheet');
  static const countdown = Key('rankings.countdown');
  static const me = Key('rankings.me');
  static Key period(LiveRankingPeriod p) => Key('rankings.period.${p.name}');
  static Key entry(String hostId) => Key('rankings.entry.$hostId');
}

/// The room's "Room rank" chip (owner ref 76): opens the popularity board.
class LiveRankChip extends StatelessWidget {
  const new({super.key});

  static const chipKey = Key('rankings.chip');

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      key: chipKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(showLiveRankings(context)),
      child: LiveChip(
        icon: Icons.home_rounded,
        child: Text(
          context.l10n.liveRankChip,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

/// The popularity board (CP-016 A, owner ref 74, measured at 430 pt): a
/// white sheet, the board tab (Rich waits for L3, greyed "Soon"), This hour /
/// Today / This week, the countdown to the window's end, the top three on a
/// podium, the rest as rows, and — for a host — their own row pinned at the
/// bottom. One region for everyone (owner D99).
Future<void> showLiveRankings(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000),
      barrierColor: const Color(0x00000000),
      builder: (_) => const _RankingsSheet(),
    );

abstract final class _Ink {
  static const text = Color(0xFF222222);
  static const soft = Color(0xFF9A9BA5);
  static const pill = Color(0xFFF5F7FB);
  static const points = Color(0xFFF5A300);
  static const live = Color(0xFF00C2B2);
}

class _RankingsSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_RankingsSheet> createState() => _RankingsSheetState();
}

class _RankingsSheetState extends ConsumerState<_RankingsSheet> {
  LiveRankingPeriod _period = LiveRankingPeriod.hour;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The countdown moves each 20 s; at the window's end the board reloads.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final board = ref.read(liveRankingsProvider(_period)).value;
      if (board != null && !DateTime.now().isBefore(board.endsAt)) {
        ref.invalidate(liveRankingsProvider(_period));
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _countdown(AppLocalizations l10n, DateTime endsAt) {
    var left = endsAt.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    return l10n.liveRankCountdown(
      two(left.inDays),
      two(left.inHours % 24),
      two(left.inMinutes % 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final board = ref.watch(liveRankingsProvider(_period));
    final me = ref.watch(currentUserProvider);
    final tabStyle = text.title.copyWith(fontSize: 18, height: 1.2);
    return Container(
      key: LiveRankingsKeys.sheet,
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tabs 17 pt down, 21 pt in; the active one carries a short mark.
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(21, 14, 6, 0),
            child: Row(
              children: [
                Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.liveRankTitle,
                        style: tabStyle.copyWith(
                          color: _Ink.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 8,
                      height: 3.3,
                      decoration: BoxDecoration(
                        color: _Ink.text,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 28),
                // Rich (spenders) waits for coins (L3).
                Semantics(
                  label: '${l10n.liveRankRich}, ${l10n.liveSoon}',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.liveRankRich,
                            style: tabStyle.copyWith(
                              color: _Ink.soft.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: ' ${l10n.liveSoon}',
                            style: text.caption.copyWith(
                              color: _Ink.soft,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.liveClose,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _Ink.text,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // This hour · Today · This week: pills 26 pt tall on #F5F7FB.
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final p in LiveRankingPeriod.values) ...[
                  _PeriodPill(
                    key: LiveRankingsKeys.period(p),
                    label: switch (p) {
                      LiveRankingPeriod.hour => l10n.liveRankHour,
                      LiveRankingPeriod.day => l10n.liveRankDay,
                      LiveRankingPeriod.week => l10n.liveRankWeek,
                    },
                    selected: p == _period,
                    onTap: () => setState(() => _period = p),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 17),
            child: Text(
              board.value == null ? '' : _countdown(l10n, board.value!.endsAt),
              key: LiveRankingsKeys.countdown,
              style: text.body.copyWith(color: _Ink.soft, fontSize: 14),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: switch (board) {
              AsyncData(:final value) when value.entries.isEmpty => Center(
                child: Text(
                  l10n.liveRankEmpty,
                  style: text.body.copyWith(color: _Ink.soft),
                ),
              ),
              AsyncData(:final value) => ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  _Podium(entries: value.entries.take(3).toList()),
                  for (final e in value.entries.skip(3)) _Row.of(e, context),
                ],
              ),
              AsyncError(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    failureMessage(l10n, toAppFailure(error)),
                    textAlign: TextAlign.center,
                    style: text.body.copyWith(color: _Ink.soft),
                  ),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          if (board.value case final b? when b.isHost && me != null)
            _MeRow(
              rank: b.myRank,
              points: b.myPoints,
              name: me.displayName,
              url: me.liveCoverUrl ?? me.avatarUrl,
            ),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12.6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _Ink.pill,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: context.textStyles.body.copyWith(
            fontSize: 15,
            color: selected ? _Ink.text : _Ink.soft,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

/// A host's picture as a rounded square, with LIVE when they are on air.
class _Picture extends StatelessWidget {
  const new({
    required this.name,
    required this.url,
    required this.isLive,
    required this.size,
    this.height,
  });

  new of(LiveRankingEntry e, {required double size})
    : this(
        name: e.host.displayName,
        url: e.coverUrl ?? e.host.avatarUrl,
        isLive: e.isLive,
        size: size,
      );

  final String name;
  final String? url;
  final bool isLive;

  /// The width, and the height unless [height] is given.
  final double size;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return SizedBox(
      width: size,
      height: height ?? size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.12),
              child: url == null
                  ? ColoredBox(
                      color: const Color(0xFF1C1B1F),
                      child: Center(
                        child: Text(
                          name.characters.firstOrNull ?? '',
                          style: context.textStyles.title.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontSize: size * 0.4,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0xFF1C1B1F)),
                    ),
            ),
          ),
          if (isLive)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Container(
                height: size * 0.22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(size * 0.12),
                  ),
                ),
                child: Text(
                  context.l10n.liveRankLive,
                  style: context.textStyles.caption.copyWith(
                    color: _Ink.live,
                    fontSize: size * 0.14,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const new({required this.points, this.size = 15});

  final int points;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      KCherryIcon(size: size + 1),
      const SizedBox(width: 2),
      Text(
        KFormat.compact(points, context.l10n),
        style: context.textStyles.bodyStrong.copyWith(
          color: _Ink.points,
          fontSize: size,
        ),
      ),
    ],
  );
}

/// #2 · #1 · #3, the first raised and gold (ref 74).
/// A top-3 picture inside the owner's frame for its rank
/// (`assets/live_rank_frames/`, with the rank number drawn in). The picture
/// fills the frame's inner window (measured on the originals, see
/// PROVENANCE.md), drawn under the frame and a little larger so no gap shows;
/// LIVE is a small tag at the window's top corner, clear of the gems.
class _FramedPicture extends StatelessWidget {
  const new({required this.entry, required this.size});

  final LiveRankingEntry entry;
  final double size;

  /// Inner window per rank: left, top, right, bottom, as fractions of the side.
  static const _windows = <int, (double, double, double, double)>{
    1: (0.176, 0.331, 0.821, 0.861),
    2: (0.199, 0.293, 0.801, 0.872),
    3: (0.188, 0.315, 0.811, 0.861),
  };

  @override
  Widget build(BuildContext context) {
    final (l, t, r, b) = _windows[entry.rank]!;
    const bleed = 0.01;
    final left = (l - bleed) * size;
    final top = (t - bleed) * size;
    final width = (r - l + 2 * bleed) * size;
    final height = (b - t + 2 * bleed) * size;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: _Picture(
              name: entry.host.displayName,
              url: entry.coverUrl ?? entry.host.avatarUrl,
              isLive: false,
              size: width,
              height: height,
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              'assets/live_rank_frames/frame_${entry.rank}.webp',
              fit: BoxFit.contain,
            ),
          ),
          if (entry.isLive)
            PositionedDirectional(
              start: left + width * 0.08,
              top: top + height * 0.1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.l10n.liveRankLive,
                  style: context.textStyles.caption.copyWith(
                    color: _Ink.live,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const new({required this.entries});

  final List<LiveRankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    LiveRankingEntry? at(int rank) =>
        entries.where((e) => e.rank == rank).firstOrNull;
    Widget card(LiveRankingEntry? e, {required bool first}) => Expanded(
      child: e == null
          ? const SizedBox()
          : Semantics(
              key: LiveRankingsKeys.entry(e.host.id),
              label: context.l10n.liveRankRow(
                e.rank,
                e.host.displayName,
                context.l10n.liveScore(e.points, KFormat.grouped(e.points)),
              ),
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: first
                        ? const [Color(0xFFFFF1C7), Color(0xFFFFFBEF)]
                        : e.rank == 2
                        ? const [Color(0xFFEDF2FF), Color(0xFFFBFCFF)]
                        : const [Color(0xFFFFEEF2), Color(0xFFFFFBFC)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FramedPicture(entry: e, size: first ? 104 : 92),
                    const SizedBox(height: 2),
                    Text(
                      KFormat.bidiIsolate(e.host.displayName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.bodyStrong.copyWith(
                        color: _Ink.text,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _Points(points: e.points, size: 14),
                  ],
                ),
              ),
            ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          card(at(2), first: false),
          const SizedBox(width: 7),
          card(at(1), first: true),
          const SizedBox(width: 7),
          card(at(3), first: false),
        ],
      ),
    );
  }
}

/// Rank 4 and below: 63.8 pt rows, a 44 pt picture.
class _Row extends StatelessWidget {
  const new({
    required this.rankLabel,
    required this.name,
    required this.picture,
    required this.points,
    required this.semantics,
    super.key,
  });

  new of(LiveRankingEntry e, BuildContext context)
    : this(
        key: LiveRankingsKeys.entry(e.host.id),
        rankLabel: '${e.rank}',
        name: e.host.displayName,
        picture: _Picture.of(e, size: 44),
        points: e.points,
        semantics: context.l10n.liveRankRow(
          e.rank,
          e.host.displayName,
          context.l10n.liveScore(e.points, KFormat.grouped(e.points)),
        ),
      );

  final String rankLabel;
  final String name;
  final Widget picture;
  final int points;
  final String semantics;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semantics,
    excludeSemantics: true,
    child: SizedBox(
      height: 63.8,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                rankLabel,
                textAlign: TextAlign.center,
                style: context.textStyles.title.copyWith(
                  color: _Ink.soft,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 10),
            picture,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                KFormat.bidiIsolate(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodyStrong.copyWith(
                  color: _Ink.text,
                  fontSize: 16.5,
                ),
              ),
            ),
            _Points(points: points),
          ],
        ),
      ),
    ),
  );
}

/// The caller's own row (a host), pinned under the list.
class _MeRow extends StatelessWidget {
  const new({
    required this.rank,
    required this.points,
    required this.name,
    required this.url,
  });

  final int? rank;
  final int points;
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: LiveRankingsKeys.me,
    decoration: const BoxDecoration(
      color: Color(0xFFFFFFFF),
      boxShadow: [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 8,
          offset: Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: _Row(
        key: const Key('rankings.me.row'),
        rankLabel: rank == null ? '—' : '$rank',
        name: name,
        picture: _Picture(name: name, url: url, isLive: false, size: 44),
        points: points,
        semantics: context.l10n.liveRankRow(
          rank ?? 0,
          name,
          context.l10n.liveScore(points, KFormat.grouped(points)),
        ),
      ),
    ),
  );
}
