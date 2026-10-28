import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_room_stats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart'
    show formatLiveDuration;
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D140: the host's statistics of a live (`GET /live/rooms/{roomId}/stats`)
/// for the end-of-live summary.
final FutureProviderFamily<LiveRoomStats, String> liveRoomStatsProvider =
    FutureProvider.autoDispose.family(
      (ref, roomId) => ref.watch(liveRepositoryProvider).roomStats(roomId),
    );

/// The numbers of the summary line up (tabular figures).
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// The widest the summary's column grows (tablets, landscape).
const double _maxWidth = 560;

/// The recap's palette: Kabso red is the one accent; the metals mark rank.
abstract final class _Ink {
  static const Color gold = KBrandColors.gold;
  static const silver = Color(0xFFC9CED6);
  static const bronze = Color(0xFFD08A4E);

  /// The country slices, in order (validated for the dark surface with the
  /// dataviz checks: adjacent CVD ΔE ≥ 8.4, normal-vision ΔE ≥ 19.8, all
  /// ≥ 3:1 on `#16161A`); `OTHER` and `UNKNOWN` stay neutral.
  static const List<Color> series = [
    Color(0xFFFF3B47),
    Color(0xFF3987E5),
    Color(0xFFC98500),
    Color(0xFF199E70),
    Color(0xFF9085E9),
  ];
  static const other = Color(0xFF70707C);
  static const unknown = Color(0xFF4A4A55);

  static Color metal(int rank) => switch (rank) {
    1 => gold,
    2 => silver,
    _ => bronze,
  };
}

/// D140, D140b (owner: «صفحة انتهاء البث بملء الشاشة … ومعلومات أكثر منها
/// دول المشاهدين ونسبة المشاهدة لكل دولة», «اجعله احترافياً», «إطارات
/// لأفضل الداعمين»): the host's live recap, full screen, from
/// `GET /live/rooms/{roomId}/stats` only (CONVENTIONS §10.31) — a hero (the
/// host in a turning ring or their CP frame, the time live, the cherries
/// counting up and their gifts / taps split), the audience in one card, the
/// secondary numbers as chips, the viewers' countries as a ring chart with
/// its legend, the top three in Kabso's gold, silver and bronze frames on a
/// podium, and the charm level. Honest states: placeholders shaped like the
/// page while loading, an error with a retry, and quiet lines when there is
/// nothing to show.
class GoLiveSummary extends StatelessWidget {
  const new({
    required this.localDuration,
    required this.onDone,
    super.key,
    this.stats,
    this.loading = false,
    this.failed = false,
    this.onRetry,
    this.hostName = '',
    this.hostAvatarUrl,
    this.hostCpFrame = false,
    this.charm,
    this.doneKey,
  });

  /// The app's own count from going live to the end; shown until (and
  /// unless) the server's arrives.
  final Duration localDuration;
  final VoidCallback onDone;

  /// The live's statistics; `null` while [loading] or when [failed].
  final LiveRoomStats? stats;
  final bool loading;
  final bool failed;

  /// Reads the statistics again (`null`: nothing to retry).
  final VoidCallback? onRetry;
  final String hostName;
  final String? hostAvatarUrl;

  /// The host's couple unlocked the CP Special Frame (D112): the hero
  /// shows it instead of the turning ring.
  final bool hostCpFrame;
  final LevelSummary? charm;
  final Key? doneKey;

  static const pointsKey = Key('summary.points');
  static const tapsKey = Key('summary.taps');
  static const giftsKey = Key('summary.gifts');
  static const supportersKey = Key('summary.supporters');
  static const charmKey = Key('summary.charm');
  static const viewersKey = Key('summary.viewers');
  static const peakKey = Key('summary.peak');
  static const followersKey = Key('summary.followers');
  static const chatKey = Key('summary.chat');
  static const giftCountKey = Key('summary.giftCount');

  /// D154d: the gifts' value and the host's earnings.
  static const giftCoinsKey = Key('summary.giftCoins');
  static const earningsKey = Key('summary.earnings');
  static const countriesKey = Key('summary.countries');
  static const donutKey = Key('summary.donut');
  static const noViewersKey = Key('summary.noViewers');
  static const podiumKey = Key('summary.podium');
  static const loadingKey = Key('summary.loading');
  static const errorKey = Key('summary.error');
  static const hostFrameKey = Key('summary.hostFrame');
  static Key countryKey(String code) => Key('summary.country.$code');
  static Key rankFrameKey(int rank) => Key('summary.rankFrame.$rank');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stats = this.stats;
    final charm = this.charm;
    final viewers = stats?.viewers;
    const gap = SizedBox(height: KSpacing.lg);
    final sections = <Widget>[
      _Hero(
        hostName: hostName,
        hostAvatarUrl: hostAvatarUrl,
        hostCpFrame: hostCpFrame,
        duration: stats?.duration ?? localDuration,
        stats: stats,
        loading: loading,
      ),
      const SizedBox(height: KSpacing.xxl),
      if (loading)
        const _Loading(key: loadingKey)
      else if (stats == null) ...[
        if (failed) _ErrorPanel(key: errorKey, onRetry: onRetry),
      ] else ...[
        _KeyStats(stats: stats),
        const SizedBox(height: KSpacing.md),
        _SecondaryChips(stats: stats),
        // D154d (owner): the gifts' value and the host's share of it.
        const SizedBox(height: KSpacing.sm),
        _ValueChips(stats: stats),
        if (viewers != null) ...[
          gap,
          if (viewers.unique == 0)
            _QuietPanel(
              key: noViewersKey,
              icon: Icons.visibility_outlined,
              text: context.l10n.liveStatsNoViewers,
            )
          else
            _CountriesPanel(
              key: countriesKey,
              total: viewers.unique,
              countries: stats.viewerCountries,
            ),
        ],
        gap,
        _PodiumPanel(key: podiumKey, stats: stats),
      ],
      if (charm != null && charm.available && charm.level != null) ...[
        gap,
        _CharmPanel(key: charmKey, charm: charm),
      ],
    ];
    return ColoredBox(
      color: p.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _Glow(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      KSpacing.lg,
                      KSpacing.xl,
                      KSpacing.lg,
                      KSpacing.xxl,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: sections,
                        ),
                      ),
                    ),
                  ),
                ),
                _DoneBar(onDone: onDone, doneKey: doneKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Surfaces --------------------------------------------------------------

/// A soft red light behind the hero, fading into the background.
class _Glow extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.1),
            radius: 1.1,
            colors: [
              p.primary.withValues(alpha: 0.28),
              p.primary.withValues(alpha: 0.06),
              p.background.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

/// The recap's card: a raised surface lit from the top (a faint gradient
/// and a hairline highlight), 24 pt corners, no heavy border.
class _Panel extends StatelessWidget {
  const new({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final title = this.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.surfaceRaised, p.surface],
        ),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.lg + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(height: KSpacing.lg),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

// ---- Hero ------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const new({
    required this.hostName,
    required this.hostAvatarUrl,
    required this.hostCpFrame,
    required this.duration,
    required this.stats,
    required this.loading,
  });

  final String hostName;
  final String? hostAvatarUrl;
  final bool hostCpFrame;
  final Duration duration;
  final LiveRoomStats? stats;
  final bool loading;

  static const double avatar = 84;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final stats = this.stats;
    return Column(
      children: [
        if (hostCpFrame)
          CpSpecialFrameAvatar(
            key: GoLiveSummary.hostFrameKey,
            width: CpSpecialFrameAvatar.widthForAvatar(avatar),
            name: hostName,
            imageUrl: hostAvatarUrl,
          )
        else
          _TurningRing(
            size: avatar + 12,
            child: KAvatar(
              name: hostName,
              imageUrl: hostAvatarUrl,
              size: avatar,
            ),
          ),
        const SizedBox(height: KSpacing.md),
        Semantics(
          header: true,
          child: Text(
            l10n.goLiveEndedTitle,
            textAlign: TextAlign.center,
            style: t.headline.copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        _Pill(
          icon: Icons.schedule_rounded,
          label: l10n.goLiveSummaryTime,
          value: formatLiveDuration(duration),
        ),
        const SizedBox(height: KSpacing.xl),
        if (loading) ...[
          const KSkeleton(width: 200, height: 56, radius: KRadius.md),
          const SizedBox(height: KSpacing.lg),
          const KSkeleton(height: 10, radius: KRadius.pill),
        ] else if (stats != null) ...[
          Semantics(
            key: GoLiveSummary.pointsKey,
            label: l10n.liveHostPillPoints(KFormat.grouped(stats.total)),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KCherryIcon(size: 44, animated: true),
                const SizedBox(width: KSpacing.sm),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _CountUp(
                      value: stats.total,
                      style: t.display.copyWith(
                        color: p.textPrimary,
                        fontSize: 52,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        fontFeatures: _tabular,
                        shadows: [
                          Shadow(
                            color: p.primary.withValues(alpha: 0.55),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.liveStatsCherries,
            textAlign: TextAlign.center,
            style: t.label.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.xl),
          _Split(stats: stats),
        ],
      ],
    );
  }
}

/// The host's picture in a red-to-gold ring that turns once as the recap
/// opens and then rests (still with reduced motion).
class _TurningRing extends StatefulWidget {
  const new({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  State<_TurningRing> createState() => _TurningRingState();
}

class _TurningRingState extends State<_TurningRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.value = 1;
    } else if (_turn.isDismissed) {
      _turn.forward();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _turn,
                builder: (_, _) => CustomPaint(
                  painter: _RingPainter(
                    turn: KMotion.standard.transform(_turn.value),
                    colors: [p.primary, _Ink.gold, p.primary],
                    glow: p.primary,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const new({required this.turn, required this.colors, required this.glow});

  final double turn;
  final List<Color> colors;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(1.5);
    final rotation = GradientRotation(turn * 2 * math.pi);
    canvas
      ..drawOval(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = glow.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..drawOval(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..shader = SweepGradient(
            colors: colors,
            transform: rotation,
          ).createShader(rect),
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.turn != turn;
}

/// A small glassy pill: an icon, a label and a value.
class _Pill extends StatelessWidget {
  const new({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(KRadius.pill),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: p.textSecondary),
            const SizedBox(width: KSpacing.xs + 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ),
            const SizedBox(width: KSpacing.xs + 2),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: t.label.copyWith(
                color: p.textPrimary,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cherries' split: one rounded bar (gifts in Kabso red, taps in gold,
/// a 2 pt gap between) and a legend chip for each with its share.
class _Split extends StatelessWidget {
  const new({required this.stats});

  final LiveRoomStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final gifts = stats.supportPoints;
    final taps = stats.tapPoints;
    final sum = gifts + taps;
    // Whole percents; a share that is there but rounds away reads "<1%"
    // (and its partner ">99%"), never a misleading 0 % or 100 %.
    String share(int v) {
      if (sum == 0 || v == 0) return '0%';
      if (v == sum) return '100%';
      final pct = (v * 100 / sum).round();
      if (pct < 1) return '<1%';
      if (pct > 99) return '>99%';
      return '$pct%';
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(KRadius.pill),
          child: SizedBox(
            height: 10,
            child: ColoredBox(
              color: const Color(0x14FFFFFF),
              child: sum == 0
                  ? const SizedBox.expand()
                  : _Grow(
                      builder: (f) => Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (gifts > 0)
                            Expanded(
                              flex: math.max(
                                1,
                                (gifts * 1000 / sum * f).round(),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      KBrandColors.red600,
                                      p.primary,
                                      KBrandColors.red400,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (taps > 0) ...[
                            if (gifts > 0) const SizedBox(width: 2),
                            Expanded(
                              flex: math.max(
                                1,
                                (taps * 1000 / sum * f).round(),
                              ),
                              child: const ColoredBox(color: _Ink.gold),
                            ),
                          ],
                          if (f < 1)
                            Expanded(
                              flex: math.max(1, ((1 - f) * 1000).round()),
                              child: const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: KSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: KSpacing.sm,
          runSpacing: KSpacing.sm,
          children: [
            _LegendChip(
              key: GoLiveSummary.giftsKey,
              color: p.primary,
              label: l10n.goLiveSummaryGifts,
              value: KFormat.grouped(gifts),
              share: share(gifts),
            ),
            _LegendChip(
              key: GoLiveSummary.tapsKey,
              color: _Ink.gold,
              label: l10n.goLiveSummaryTaps,
              value: KFormat.grouped(taps),
              share: share(taps),
            ),
          ],
        ),
        if (stats.hostOwnPoints > 0) ...[
          const SizedBox(height: KSpacing.md),
          Text(
            l10n.liveStatsIncludesYours(
              KFormat.bidiIsolate(KFormat.grouped(stats.hostOwnPoints)),
            ),
            textAlign: TextAlign.center,
            style: context.textStyles.caption.copyWith(color: p.textTertiary),
          ),
        ],
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const new({
    required this.color,
    required this.label,
    required this.value,
    required this.share,
    super.key,
  });

  final Color color;
  final String label;
  final String value;
  final String share;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    return Semantics(
      container: true,
      label: '$label: $value ($share)',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: KSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: t.label.copyWith(
                color: p.textPrimary,
                fontFeatures: _tabular,
              ),
            ),
            const SizedBox(width: KSpacing.xs + 2),
            Text(
              share,
              textDirection: TextDirection.ltr,
              style: t.caption.copyWith(
                color: p.textTertiary,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Key numbers -----------------------------------------------------------

/// The audience in one card: a 2 × 2 grid with hairline dividers.
class _KeyStats extends StatelessWidget {
  const new({required this.stats});

  final LiveRoomStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewers = stats.viewers;
    String n(int v) => KFormat.grouped(v);
    final cells = <Widget>[
      if (viewers != null) ...[
        _Stat(
          key: GoLiveSummary.viewersKey,
          icon: Icons.visibility_outlined,
          label: l10n.liveStatsViewers,
          value: n(viewers.unique),
        ),
        _Stat(
          key: GoLiveSummary.peakKey,
          icon: Icons.trending_up_rounded,
          label: l10n.liveStatsPeak,
          value: n(viewers.peak),
        ),
        _Stat(
          icon: Icons.timelapse_rounded,
          label: l10n.liveStatsAverageWatch,
          value: formatLiveDuration(viewers.averageWatch),
        ),
      ],
      _Stat(
        key: GoLiveSummary.followersKey,
        icon: Icons.person_add_alt_rounded,
        label: l10n.liveStatsNewFollowers,
        value: n(stats.newFollowers),
      ),
    ];
    final p = context.palette;
    final divider = ColoredBox(color: p.border.withValues(alpha: 0.5));
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: 1, child: divider));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cells[i]),
              if (i + 1 < cells.length) ...[
                SizedBox(width: 1, child: divider),
                Expanded(child: cells[i + 1]),
              ],
            ],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.surfaceRaised, p.surface],
        ),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.lg + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: KBrandColors.red400),
            ),
            const SizedBox(height: KSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                style: t.headline.copyWith(
                  color: p.textPrimary,
                  fontSize: 26,
                  fontFeatures: _tabular,
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat messages, gifts sent and supporters as one row of compact chips.
class _SecondaryChips extends StatelessWidget {
  const new({required this.stats});

  final LiveRoomStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String n(int v) => KFormat.grouped(v);
    final chips = [
      _Chip(
        key: GoLiveSummary.chatKey,
        icon: Icons.chat_bubble_outline_rounded,
        label: l10n.liveStatsChatMessages,
        value: n(stats.chatMessages),
      ),
      _Chip(
        key: GoLiveSummary.giftCountKey,
        icon: Icons.card_giftcard_rounded,
        label: l10n.liveStatsGiftsSent,
        value: n(stats.giftCount),
      ),
      _Chip(
        key: GoLiveSummary.supportersKey,
        icon: Icons.volunteer_activism_outlined,
        label: l10n.goLiveSummarySupporters,
        value: n(stats.supporters),
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, chip) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: KSpacing.sm),
            Expanded(child: chip),
          ],
        ],
      ),
    );
  }
}

/// D154d: the gifts' value in coins and the host's share (display only).
class _ValueChips extends StatelessWidget {
  const new({required this.stats});

  final LiveRoomStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Chip(
              key: GoLiveSummary.giftCoinsKey,
              icon: Icons.toll_rounded,
              label: l10n.liveStatsGiftCoins,
              value: KFormat.grouped(stats.giftCoins),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: _Chip(
              key: GoLiveSummary.earningsKey,
              icon: Icons.savings_outlined,
              label: l10n.liveStatsEarnings,
              value: KFormat.grouped(stats.earningsCoins),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.md,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(KRadius.lg),
          border: Border.all(color: const Color(0x0FFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: p.textTertiary),
                const SizedBox(width: KSpacing.xs + 2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value,
                      textDirection: TextDirection.ltr,
                      style: t.bodyStrong.copyWith(
                        color: p.textPrimary,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: p.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Countries -------------------------------------------------------------

/// Where the viewers came from: a ring chart (the total in its centre) and
/// its legend — swatch, flag, name, viewers, share, and a thin bar.
class _CountriesPanel extends StatelessWidget {
  const new({required this.total, required this.countries, super.key});

  final int total;
  final List<LiveViewerCountry> countries;

  static Color colorOf(int index, String code) => switch (code) {
    LiveViewerCountry.other => _Ink.other,
    LiveViewerCountry.unknown => _Ink.unknown,
    _ => _Ink.series[index % _Ink.series.length],
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = [
      for (final (i, c) in countries.indexed) colorOf(i, c.country),
    ];
    return _Panel(
      title: l10n.liveStatsCountriesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _Donut(
              key: GoLiveSummary.donutKey,
              shares: [for (final c in countries) c.viewers / total],
              colors: colors,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    KFormat.grouped(total),
                    textDirection: TextDirection.ltr,
                    style: t.headline.copyWith(
                      color: p.textPrimary,
                      fontFeatures: _tabular,
                    ),
                  ),
                  Text(
                    l10n.liveStatsViewers,
                    style: t.caption.copyWith(color: p.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KSpacing.xl),
          for (final (i, c) in countries.indexed) ...[
            if (i > 0) const SizedBox(height: KSpacing.md + 2),
            _CountryRow(
              key: GoLiveSummary.countryKey(c.country),
              country: c,
              name: _countryName(context, c.country, arabic: arabic),
              color: colors[i],
            ),
          ],
          const SizedBox(height: KSpacing.lg),
          Text(
            l10n.liveStatsCountriesNote(
              KFormat.bidiIsolate(KFormat.grouped(total)),
            ),
            style: t.caption.copyWith(color: p.textTertiary),
          ),
        ],
      ),
    );
  }

  static String _countryName(
    BuildContext context,
    String code, {
    required bool arabic,
  }) {
    final l10n = context.l10n;
    if (code == LiveViewerCountry.other) return l10n.liveStatsCountryOther;
    if (code == LiveViewerCountry.unknown) return l10n.liveStatsCountryUnknown;
    final country = KCountries.byCode(code);
    return country == null ? code : KCountries.name(country, arabic: arabic);
  }
}

/// A ring chart: one slice a share, clockwise from the top, a 2 pt gap
/// between slices; it sweeps in once (whole with reduced motion).
class _Donut extends StatelessWidget {
  const new({
    required this.shares,
    required this.colors,
    required this.center,
    super.key,
  });

  final List<double> shares;
  final List<Color> colors;
  final Widget center;

  static const double size = 168;
  static const double stroke = 18;

  @override
  Widget build(BuildContext context) {
    final track = context.palette.surfaceOverlay;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: _Grow(
          builder: (f) => CustomPaint(
            painter: _DonutPainter(
              shares: shares,
              colors: colors,
              progress: f,
              track: track,
            ),
            child: Center(child: center),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const new({
    required this.shares,
    required this.colors,
    required this.progress,
    required this.track,
  });

  final List<double> shares;
  final List<Color> colors;
  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = _Donut.stroke;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final radius = rect.width / 2;
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    // A 2 pt gap at the ring's middle line, as an angle.
    final gap = shares.where((s) => s > 0).length > 1 ? 2 / radius : 0.0;
    var start = -math.pi / 2;
    final total = 2 * math.pi * progress;
    var drawn = 0.0;
    for (var i = 0; i < shares.length; i++) {
      final sweep = 2 * math.pi * shares[i];
      if (sweep <= 0) continue;
      final visible = math.min(sweep, total - drawn);
      if (visible <= 0) break;
      final arc = math.max<double>(0, visible - gap);
      canvas.drawArc(
        rect,
        start + gap / 2,
        arc,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[i],
      );
      start += sweep;
      drawn += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.shares != shares;
}

class _CountryRow extends StatelessWidget {
  const new({
    required this.country,
    required this.name,
    required this.color,
    super.key,
  });

  final LiveViewerCountry country;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final percent = '${country.percent.toStringAsFixed(1)}%';
    const lead = 8 + KSpacing.sm + _Flag.width + KSpacing.md;
    return Semantics(
      container: true,
      label: l10n.liveStatsCountryRow(
        name,
        percent,
        KFormat.grouped(country.viewers),
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: KSpacing.sm),
              _Flag(code: country.country),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Text(
                KFormat.grouped(country.viewers),
                textDirection: TextDirection.ltr,
                style: t.caption.copyWith(
                  color: p.textTertiary,
                  fontFeatures: _tabular,
                ),
              ),
              const SizedBox(width: KSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 52),
                child: Text(
                  percent,
                  textAlign: TextAlign.end,
                  textDirection: TextDirection.ltr,
                  softWrap: false,
                  style: t.label.copyWith(
                    color: p.textPrimary,
                    fontFeatures: _tabular,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs + 2),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: lead),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KRadius.pill),
              child: SizedBox(
                height: 4,
                child: ColoredBox(
                  color: const Color(0x10FFFFFF),
                  child: _Grow(
                    builder: (f) => FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: (country.percent / 100 * f).clamp(0.0, 1.0),
                      child: ColoredBox(color: color),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A country's flag (Noto Color Emoji art, `assets/flags/`), or a quiet
/// symbol for `OTHER` and `UNKNOWN`.
class _Flag extends StatelessWidget {
  const new({required this.code});

  final String code;

  static const double width = 24;
  static const double height = 18;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget symbol(IconData icon) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.surfaceOverlay,
        borderRadius: BorderRadius.circular(KRadius.xs),
      ),
      child: Icon(icon, size: 12, color: p.textSecondary),
    );
    return switch (code) {
      LiveViewerCountry.other => symbol(Icons.public_rounded),
      LiveViewerCountry.unknown => symbol(Icons.question_mark_rounded),
      _ => Image.asset(
        'assets/flags/${code.toLowerCase()}.webp',
        width: width,
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => symbol(Icons.flag_outlined),
      ),
    };
  }
}

// ---- Top supporters --------------------------------------------------------

/// The top three on a podium, each in Kabso's winged, crowned frame for
/// their place (`assets/leaderboard/podium_frame_*.webp`, D84 art): gold
/// first in the middle and highest, silver at the reading start, bronze at
/// the end.
class _PodiumPanel extends StatelessWidget {
  const new({required this.stats, super.key});

  final LiveRoomStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final top = stats.topSupporters;
    return _Panel(
      title: l10n.liveStatsTopSupporters,
      child: top.isEmpty
          ? Text(
              l10n.liveStatsNoSupporters,
              style: t.body.copyWith(color: p.textSecondary),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final rank in const [2, 1, 3])
                  Expanded(
                    flex: rank == 1 ? 6 : 5,
                    child: rank <= top.length
                        ? _Step(rank: rank, supporter: top[rank - 1])
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
    );
  }
}

class _Step extends StatelessWidget {
  const new({required this.rank, required this.supporter});

  final int rank;
  final LiveStatsSupporter supporter;

  static const _blockHeight = {1: 64.0, 2: 46.0, 3: 34.0};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final metal = _Ink.metal(rank);
    final name = supporter.user.displayName;
    return Semantics(
      container: true,
      label: l10n.liveStatsSupporterRank(
        rank,
        name,
        KFormat.grouped(supporter.points),
      ),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          final frame = math.min(c.maxWidth, rank == 1 ? 128.0 : 104.0);
          return Column(
            children: [
              _RankFrame(
                key: GoLiveSummary.rankFrameKey(rank),
                rank: rank,
                width: frame,
                name: name,
                imageUrl: supporter.user.avatarUrl,
              ),
              const SizedBox(height: KSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: t.label.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(height: KSpacing.xxs),
              KCherryAmount(
                supporter.points,
                size: 14,
                style: t.caption.copyWith(
                  color: p.textSecondary,
                  fontFeatures: _tabular,
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              Container(
                height: _blockHeight[rank],
                margin: const EdgeInsets.symmetric(horizontal: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KRadius.md),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      metal.withValues(alpha: 0.42),
                      metal.withValues(alpha: 0.12),
                      metal.withValues(alpha: 0.02),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: metal.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Text(
                  '$rank',
                  style: t.headline.copyWith(
                    color: metal,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    fontFeatures: _tabular,
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

/// A supporter's picture inside the podium frame of [rank]: the picture
/// fills the frame's round opening (measured on the art, D84), the frame is
/// drawn over it.
class _RankFrame extends StatelessWidget {
  const new({
    required this.rank,
    required this.width,
    required this.name,
    required this.imageUrl,
    super.key,
  });

  final int rank;
  final double width;
  final String name;
  final String? imageUrl;

  /// Per rank: the opening's centre (fraction of the height), its radius
  /// (fraction of the width) and the art's aspect (height / width).
  static const _hole = <int, (double, double, double)>{
    1: (0.557, 0.243, 461 / 480),
    2: (0.554, 0.230, 415 / 480),
    3: (0.571, 0.226, 375 / 480),
  };

  @override
  Widget build(BuildContext context) {
    final (cy, r, aspect) = _hole[rank]!;
    final height = width * aspect;
    final photo = (r * width + 2) * 2;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: width / 2 - photo / 2,
            top: cy * height - photo / 2,
            child: KAvatar(name: name, imageUrl: imageUrl, size: photo),
          ),
          Positioned.fill(
            child: Image.asset(
              'assets/leaderboard/podium_frame_$rank.webp',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Charm -----------------------------------------------------------------

/// The host's charm level and the way to the next, in the tier's colours.
class _CharmPanel extends StatelessWidget {
  const new({required this.charm, super.key});

  final LevelSummary charm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final level = charm.level!;
    final tier = CharmTier.of(level.levelNumber);
    final toNext = charm.pointsToNext;
    final percent = charm.progressPercent;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CharmLevelBadge(level: level.levelNumber, height: 18),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Text(
                  l10n.goLiveSummaryCharm(
                    KFormat.bidiIsolate(KFormat.grouped(level.levelNumber)),
                  ),
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
              ),
              if (percent != null)
                Text(
                  '${percent.round()}%',
                  textDirection: TextDirection.ltr,
                  style: t.label.copyWith(
                    color: p.textSecondary,
                    fontFeatures: _tabular,
                  ),
                ),
            ],
          ),
          if (percent != null) ...[
            const SizedBox(height: KSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(KRadius.pill),
              child: SizedBox(
                height: 8,
                child: ColoredBox(
                  color: p.surfaceOverlay,
                  child: _Grow(
                    builder: (f) => FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: ((percent / 100) * f).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tier.pillStart, tier.pillEnd],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (toNext != null && !charm.maxLevel) ...[
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.goLiveSummaryCharmNext(
                KFormat.bidiIsolate(
                  toNext.isValidInt
                      ? KFormat.grouped(toNext.toInt())
                      : toNext.toString(),
                ),
              ),
              style: t.caption.copyWith(color: p.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- States ----------------------------------------------------------------

/// A quiet line in a card (nothing to show, said plainly).
class _QuietPanel extends StatelessWidget {
  const new({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.surfaceOverlay,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: p.textSecondary),
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Text(text, style: t.body.copyWith(color: p.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const new({required this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onRetry = this.onRetry;
    if (onRetry == null) {
      return _QuietPanel(
        icon: Icons.cloud_off_rounded,
        text: l10n.liveStatsLoadFailed,
      );
    }
    return _Panel(
      child: KErrorState(
        title: l10n.liveStatsLoadFailed,
        message: l10n.liveStatsLoadFailedBody,
        retryLabel: l10n.actionRetry,
        onRetry: onRetry,
        embedded: true,
      ),
    );
  }
}

/// Placeholders shaped like the page: the audience card, the chips and the
/// ring chart.
class _Loading extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.loading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KSkeleton(height: 220, radius: KRadius.xl),
          const SizedBox(height: KSpacing.md),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: KSpacing.sm),
                const Expanded(
                  child: KSkeleton(height: 64, radius: KRadius.lg),
                ),
              ],
            ],
          ),
          const SizedBox(height: KSpacing.lg),
          const KSkeleton(height: 300, radius: KRadius.xl),
        ],
      ),
    );
  }
}

/// The Done button, pinned over the content's end, which fades under it.
class _DoneBar extends StatelessWidget {
  const new({required this.onDone, required this.doneKey});

  final VoidCallback onDone;
  final Key? doneKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.background.withValues(alpha: 0.6), p.background],
          stops: const [0, 0.35],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.md,
            KSpacing.lg,
            KSpacing.md,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: KButton(
                key: doneKey,
                label: context.l10n.goLiveDone,
                onPressed: onDone,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Motion ----------------------------------------------------------------

/// A number counting up from 0 once (at once with reduced motion).
class _CountUp extends StatelessWidget {
  const new({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    Text text(int v) => Text(
      KFormat.grouped(v),
      textDirection: TextDirection.ltr,
      style: style,
    );
    if (MediaQuery.disableAnimationsOf(context) || value == 0) {
      return text(value);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: _Grow.duration,
      curve: KMotion.standard,
      builder: (_, v, _) => text(v.round()),
    );
  }
}

/// Grows a mark from 0 to its value once (at once with reduced motion).
class _Grow extends StatelessWidget {
  const new({required this.builder});

  final Widget Function(double fraction) builder;

  static const duration = Duration(milliseconds: 1100);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return builder(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: KMotion.standard,
      builder: (_, f, _) => builder(f),
    );
  }
}
