import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
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

/// The podium's ring colours (rank 1 is the brand gold).
const Color _silver = Color(0xFFC9CED6);
const Color _bronze = Color(0xFFD08A4E);

/// The widest the summary's column grows (tablets, landscape).
const double _maxWidth = 560;

/// D140 (owner: «صفحة انتهاء البث بملء الشاشة … طريقة عرض المعلومات أكثر
/// إبداعاً … ومعلومات أكثر منها دول المشاهدين ونسبة المشاهدة لكل دولة»,
/// «اجعله احترافياً»): the host's end-of-live summary, full screen, from
/// `GET /live/rooms/{roomId}/stats` only (CONVENTIONS §10.31) — the cherries
/// with gifts and taps apart, the live time, the audience (unique, peak,
/// average watch), new followers, chat messages, gifts, supporters with the
/// top three, the viewers' countries with their shares, and the host's charm
/// level. Honest states: a skeleton while loading, an error with a retry,
/// and quiet lines when there is nothing to show.
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

  /// Reads the statistics again (`null`: nothing to retry, e.g. the live
  /// never got a room).
  final VoidCallback? onRetry;
  final String hostName;
  final String? hostAvatarUrl;
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
  static const countriesKey = Key('summary.countries');
  static const noViewersKey = Key('summary.noViewers');
  static const podiumKey = Key('summary.podium');
  static const loadingKey = Key('summary.loading');
  static const errorKey = Key('summary.error');
  static Key countryKey(String code) => Key('summary.country.$code');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stats = this.stats;
    final charm = this.charm;
    final viewers = stats?.viewers;
    final sections = <Widget>[
      _Hero(
        hostName: hostName,
        hostAvatarUrl: hostAvatarUrl,
        stats: stats,
        loading: loading,
      ),
      const SizedBox(height: KSpacing.xl),
      if (loading)
        const _LoadingTiles(key: loadingKey)
      else ...[
        _StatGrid(duration: stats?.duration ?? localDuration, stats: stats),
        if (stats == null && failed) ...[
          const SizedBox(height: KSpacing.lg),
          _ErrorCard(key: errorKey, onRetry: onRetry),
        ],
        if (stats != null && viewers != null) ...[
          const SizedBox(height: KSpacing.lg),
          if (viewers.unique == 0)
            _QuietCard(
              key: noViewersKey,
              icon: Icons.visibility_outlined,
              text: context.l10n.liveStatsNoViewers,
            )
          else
            _CountriesCard(
              key: countriesKey,
              total: viewers.unique,
              countries: stats.viewerCountries,
            ),
        ],
        if (stats != null) ...[
          const SizedBox(height: KSpacing.lg),
          _PodiumCard(key: podiumKey, stats: stats),
        ],
      ],
      if (charm != null && charm.available && charm.level != null) ...[
        const SizedBox(height: KSpacing.lg),
        _CharmCard(key: charmKey, charm: charm),
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
                      KSpacing.xl,
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

/// A soft brand-red light behind the hero, fading into the background.
class _Glow extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.05),
            radius: 0.95,
            colors: [
              p.primary.withValues(alpha: 0.22),
              p.background.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// The host, the title and the cherries of the live with their split.
class _Hero extends StatelessWidget {
  const new({
    required this.hostName,
    required this.hostAvatarUrl,
    required this.stats,
    required this.loading,
  });

  final String hostName;
  final String? hostAvatarUrl;
  final LiveRoomStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final stats = this.stats;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.primary, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: KAvatar(name: hostName, imageUrl: hostAvatarUrl, size: 64),
          ),
        ),
        const SizedBox(height: KSpacing.md),
        Semantics(
          header: true,
          child: Text(
            l10n.goLiveEndedTitle,
            textAlign: TextAlign.center,
            style: t.title.copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(height: KSpacing.xl),
        if (loading)
          const KSkeleton(width: 160, height: 44)
        else if (stats != null) ...[
          Semantics(
            key: GoLiveSummary.pointsKey,
            label: l10n.liveHostPillPoints(KFormat.grouped(stats.total)),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KCherryIcon(size: 40, animated: true),
                const SizedBox(width: KSpacing.sm),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _CountUp(
                      value: stats.total,
                      style: t.display.copyWith(
                        color: p.textPrimary,
                        fontSize: 44,
                        height: 1.1,
                        fontFeatures: _tabular,
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
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.lg),
          _Split(stats: stats),
        ],
      ],
    );
  }
}

/// The cherries' split: gifts (brand red) and taps (white), as one bar and
/// a legend; the host's own share under it when there is one.
class _Split extends StatelessWidget {
  const new({required this.stats});

  final LiveRoomStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final gifts = stats.supportPoints;
    final taps = stats.tapPoints;
    final sum = gifts + taps;
    final tapColor = p.textPrimary.withValues(alpha: 0.72);
    Widget legend(Key key, Color dot, String label, int value) => Semantics(
      key: key,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
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
            KFormat.grouped(value),
            textDirection: TextDirection.ltr,
            style: t.label.copyWith(
              color: p.textPrimary,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        if (sum > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(KRadius.pill),
            child: SizedBox(
              height: 6,
              child: _Grow(
                builder: (f) => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (gifts > 0)
                      Expanded(
                        flex: math.max(1, (gifts * 1000 / sum * f).round()),
                        child: ColoredBox(color: p.primary),
                      ),
                    if (taps > 0) ...[
                      if (gifts > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: math.max(1, (taps * 1000 / sum * f).round()),
                        child: ColoredBox(color: tapColor),
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
        const SizedBox(height: KSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: KSpacing.xl,
          runSpacing: KSpacing.xs,
          children: [
            legend(
              GoLiveSummary.giftsKey,
              p.primary,
              l10n.goLiveSummaryGifts,
              gifts,
            ),
            legend(
              GoLiveSummary.tapsKey,
              tapColor,
              l10n.goLiveSummaryTaps,
              taps,
            ),
          ],
        ),
        if (stats.hostOwnPoints > 0) ...[
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.liveStatsIncludesYours(
              KFormat.bidiIsolate(KFormat.grouped(stats.hostOwnPoints)),
            ),
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: p.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// The key numbers as two columns of equal tiles.
class _StatGrid extends StatelessWidget {
  const new({required this.duration, required this.stats});

  final Duration duration;
  final LiveRoomStats? stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = this.stats;
    final viewers = stats?.viewers;
    String n(int v) => KFormat.grouped(v);
    final tiles = <_Tile>[
      _Tile(
        icon: Icons.schedule_rounded,
        label: l10n.goLiveSummaryTime,
        value: formatLiveDuration(duration),
      ),
      if (viewers != null) ...[
        _Tile(
          key: GoLiveSummary.viewersKey,
          icon: Icons.visibility_outlined,
          label: l10n.liveStatsViewers,
          value: n(viewers.unique),
        ),
        _Tile(
          key: GoLiveSummary.peakKey,
          icon: Icons.trending_up_rounded,
          label: l10n.liveStatsPeak,
          value: n(viewers.peak),
        ),
        _Tile(
          icon: Icons.timelapse_rounded,
          label: l10n.liveStatsAverageWatch,
          value: formatLiveDuration(viewers.averageWatch),
        ),
      ],
      if (stats != null) ...[
        _Tile(
          key: GoLiveSummary.followersKey,
          icon: Icons.person_add_alt_rounded,
          label: l10n.liveStatsNewFollowers,
          value: n(stats.newFollowers),
        ),
        _Tile(
          key: GoLiveSummary.chatKey,
          icon: Icons.chat_bubble_outline_rounded,
          label: l10n.liveStatsChatMessages,
          value: n(stats.chatMessages),
        ),
        _Tile(
          key: GoLiveSummary.giftCountKey,
          icon: Icons.card_giftcard_rounded,
          label: l10n.liveStatsGiftsSent,
          value: n(stats.giftCount),
        ),
        _Tile(
          key: GoLiveSummary.supportersKey,
          icon: Icons.volunteer_activism_outlined,
          label: l10n.goLiveSummarySupporters,
          value: n(stats.supporters),
        ),
      ],
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = KSpacing.md;
        final width = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, tile) in tiles.indexed)
              SizedBox(
                // An odd last tile takes the whole row.
                width: tiles.length.isOdd && i == tiles.length - 1
                    ? c.maxWidth
                    : width,
                child: tile,
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
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
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: p.textTertiary),
            const SizedBox(height: KSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                style: t.headline.copyWith(
                  color: p.textPrimary,
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

/// The summary's card: the raised surface, a hairline, 16 pt corners.
class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

/// A card's title.
class _CardTitle extends StatelessWidget {
  const new({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    return Semantics(
      header: true,
      child: Text(title, style: t.bodyStrong.copyWith(color: p.textPrimary)),
    );
  }
}

/// Where the viewers came from: a flag, the name, the share as a bar.
class _CountriesCard extends StatelessWidget {
  const new({required this.total, required this.countries, super.key});

  final int total;
  final List<LiveViewerCountry> countries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(title: l10n.liveStatsCountriesTitle),
          const SizedBox(height: KSpacing.lg),
          for (final (i, c) in countries.indexed) ...[
            if (i > 0) const SizedBox(height: KSpacing.lg),
            _CountryRow(
              key: GoLiveSummary.countryKey(c.country),
              country: c,
              name: _countryName(context, c.country, arabic: arabic),
              share: c.percent / 100,
              color: switch (c.country) {
                LiveViewerCountry.other ||
                LiveViewerCountry.unknown => p.textTertiary,
                _ when i == 0 => p.primary,
                _ => p.primary.withValues(alpha: 0.55),
              },
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

class _CountryRow extends StatelessWidget {
  const new({
    required this.country,
    required this.name,
    required this.share,
    required this.color,
    super.key,
  });

  final LiveViewerCountry country;
  final String name;

  /// 0–1: the share itself (a full bar is 100 %).
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final percent = '${country.percent.toStringAsFixed(1)}%';
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
              SizedBox(
                width: 52,
                child: Text(
                  percent,
                  textAlign: TextAlign.end,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
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
            padding: const EdgeInsetsDirectional.only(
              start: _Flag.width + KSpacing.md,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KRadius.pill),
              child: SizedBox(
                height: 6,
                child: ColoredBox(
                  color: p.surfaceOverlay,
                  child: _Grow(
                    builder: (f) => FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: (share * f).clamp(0.0, 1.0),
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

  static const double width = 28;
  static const double height = 21;

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
      child: Icon(icon, size: 14, color: p.textSecondary),
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

/// The top three on low plinths: the first in the middle and highest.
class _PodiumCard extends StatelessWidget {
  const new({required this.stats, super.key});

  final LiveRoomStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final top = stats.topSupporters;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(title: l10n.liveStatsTopSupporters),
          const SizedBox(height: KSpacing.lg),
          if (top.isEmpty)
            Text(
              l10n.liveStatsNoSupporters,
              style: t.body.copyWith(color: p.textSecondary),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final rank in const [2, 1, 3])
                  Expanded(
                    child: rank <= top.length
                        ? _Step(rank: rank, supporter: top[rank - 1])
                        : const SizedBox.shrink(),
                  ),
              ],
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final first = rank == 1;
    final ring = switch (rank) {
      1 => KBrandColors.gold,
      2 => _silver,
      _ => _bronze,
    };
    final name = supporter.user.displayName;
    return Semantics(
      container: true,
      label: l10n.liveStatsSupporterRank(
        rank,
        name,
        KFormat.grouped(supporter.points),
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: KAvatar(
                  name: name,
                  imageUrl: supporter.user.avatarUrl,
                  size: first ? 60 : 48,
                ),
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.label.copyWith(color: p.textPrimary),
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
              height: switch (rank) {
                1 => 44.0,
                2 => 30.0,
                _ => 20.0,
              },
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ring.withValues(alpha: 0.28),
                    ring.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KRadius.sm),
                ),
              ),
              child: Text(
                '$rank',
                style: t.label.copyWith(color: ring, height: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The host's charm level and the way to the next.
class _CharmCard extends StatelessWidget {
  const new({required this.charm, super.key});

  final LevelSummary charm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final level = charm.level!;
    final toNext = charm.pointsToNext;
    final percent = charm.progressPercent;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CharmLevelBadge(level: level.levelNumber, height: 16),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Text(
                  l10n.goLiveSummaryCharm(
                    KFormat.bidiIsolate(KFormat.grouped(level.levelNumber)),
                  ),
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
          if (percent != null) ...[
            const SizedBox(height: KSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(KRadius.pill),
              child: SizedBox(
                height: 6,
                child: ColoredBox(
                  color: p.surfaceOverlay,
                  child: _Grow(
                    builder: (f) => FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: ((percent / 100) * f).clamp(0.0, 1.0),
                      child: ColoredBox(color: p.primary),
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

/// A quiet line in a card (nothing to show, said plainly).
class _QuietCard extends StatelessWidget {
  const new({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    return _Card(
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.textTertiary),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Text(text, style: t.body.copyWith(color: p.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const new({required this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onRetry = this.onRetry;
    if (onRetry == null) {
      return _QuietCard(
        icon: Icons.cloud_off_rounded,
        text: l10n.liveStatsLoadFailed,
      );
    }
    return _Card(
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

/// Placeholders shaped like the tiles and the countries card.
class _LoadingTiles extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.loading,
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = KSpacing.md;
          final width = (c.maxWidth - gap) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < 4; i++)
                    KSkeleton(width: width, height: 104, radius: KRadius.lg),
                ],
              ),
              const SizedBox(height: KSpacing.lg),
              const KSkeleton(height: 180, radius: KRadius.lg),
            ],
          );
        },
      ),
    );
  }
}

/// The Done button over the content's end, full width.
class _DoneBar extends StatelessWidget {
  const new({required this.onDone, required this.doneKey});

  final VoidCallback onDone;
  final Key? doneKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.border.withValues(alpha: 0.5))),
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

/// Grows a bar from 0 to its share once (at once with reduced motion).
class _Grow extends StatelessWidget {
  const new({required this.builder});

  final Widget Function(double fraction) builder;

  static const duration = Duration(milliseconds: 900);

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
