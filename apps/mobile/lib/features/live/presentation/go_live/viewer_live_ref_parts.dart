import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D257 (owner: the viewer's screen «مثل التصميم ١٠٠٪»; the reference's
/// «Regional Daily Host» card, linked to Kabso's popularity board, CP-016 A):
/// the host's place on today's board — the time left in the day's window,
/// the host's picture, their rank («99+» when not on the board), their
/// points today and the gap to the host just above. A tap opens the board;
/// «–» hides it for this visit. Nothing until the board has loaded (or when
/// it cannot be read). The host's «Host Tasks» card's geometry (82.6 ×
/// 114.6 pt).
class HostDailyRankCard extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.hostName,
    super.key,
    this.avatar,
  });

  final String hostId;
  final String hostName;
  final ImageProvider? avatar;

  static const double width = 82.6;
  static const double height = 114.6;

  static const cardKey = Key('viewerLive.dailyRank');
  static const hideKey = Key('viewerLive.dailyRank.hide');
  static const rankKey = Key('viewerLive.dailyRank.rank');

  /// Tests fix the clock.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// The host's (rank, points, gap to the one above) on [board]; rank null
  /// when they are not on it.
  static ({int? rank, int points, int? gap}) standingOf(
    LiveRankings board,
    String hostId,
  ) {
    final entries = board.entries;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e.host.id != hostId) continue;
      final above = i > 0 ? entries[i - 1].points - e.points : null;
      return (rank: e.rank, points: e.points, gap: above);
    }
    return (rank: null, points: 0, gap: null);
  }

  @override
  ConsumerState<HostDailyRankCard> createState() => _HostDailyRankCardState();
}

class _HostDailyRankCardState extends ConsumerState<HostDailyRankCard> {
  bool _hidden = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_hidden) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _hms(Duration d) {
    final s = d.isNegative ? Duration.zero : d;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s.inHours)}:${two(s.inMinutes % 60)}:'
        '${two(s.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final board = ref.watch(liveRankingsProvider(LiveRankingPeriod.day)).value;
    if (board == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final standing = HostDailyRankCard.standingOf(board, widget.hostId);
    final rank = standing.rank == null
        ? '99+'
        : standing.rank! > 99
        ? '99+'
        : '${standing.rank}';
    final left = board.endsAt.difference(HostDailyRankCard.now());
    const white = Color(0xFFFFFFFF);
    TextStyle text(double size, {FontWeight weight = FontWeight.w600}) =>
        context.textStyles.caption.copyWith(
          fontSize: size,
          height: 1,
          color: white,
          fontWeight: weight,
        );
    return Semantics(
      button: true,
      label: l10n.liveDailyRankLabel(
        widget.hostName,
        rank,
        KFormat.grouped(standing.points),
      ),
      excludeSemantics: true,
      child: GestureDetector(
        key: HostDailyRankCard.cardKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showLiveRankings(context)),
        child: MediaQuery.withNoTextScaling(
          child: SizedBox(
            width: HostDailyRankCard.width,
            height: HostDailyRankCard.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0x80BFD9FF),
                        width: 0.8,
                      ),
                      gradient: const RadialGradient(
                        center: Alignment(0, -0.35),
                        radius: 0.95,
                        colors: [Color(0xFF3C86DA), Color(0xFF1B5CA6)],
                      ),
                    ),
                  ),
                ),
                // The title tab.
                Positioned(
                  top: 0,
                  left: 11,
                  right: 11,
                  height: 14,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A4E92),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        l10n.liveDailyRankTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text(6.5, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: Semantics(
                    button: true,
                    label: l10n.liveDailyRankHide,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: HostDailyRankCard.hideKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _hidden = true),
                      child: SizedBox.square(
                        dimension: 24,
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6FBF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xCCDCEBFF),
                                width: 0.7,
                              ),
                            ),
                            child: const Icon(
                              Icons.remove_rounded,
                              size: 8,
                              color: white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The time left in today's window (ref: an orange bar).
                Positioned(
                  top: 18,
                  left: 11,
                  right: 11,
                  height: 7.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6A21E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        _hms(left),
                        textDirection: TextDirection.ltr,
                        style: text(
                          6,
                          weight: FontWeight.w500,
                        ).copyWith(color: const Color(0xCCFFF3D6)),
                      ),
                    ),
                  ),
                ),
                // The host's picture.
                Positioned(
                  top: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0B0B0B),
                        border: Border.all(
                          color: const Color(0xFFE9C46A),
                          width: 0.9,
                        ),
                        image: widget.avatar == null
                            ? null
                            : DecorationImage(
                                image: widget.avatar!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 58,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      rank,
                      key: HostDailyRankCard.rankKey,
                      textDirection: TextDirection.ltr,
                      style: text(8.5, weight: FontWeight.w500),
                    ),
                  ),
                ),
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 7,
                        color: Color(0xFFFFC64A),
                      ),
                      const SizedBox(width: 1.5),
                      Text(
                        KFormat.compact(standing.points, l10n),
                        textDirection: TextDirection.ltr,
                        style: text(6.5),
                      ),
                    ],
                  ),
                ),
                if (standing.gap case final gap?)
                  Positioned(
                    top: 82,
                    left: 4,
                    right: 4,
                    child: Center(
                      child: Text(
                        l10n.liveDailyRankGap(KFormat.compact(gap, l10n)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text(5.5, weight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
