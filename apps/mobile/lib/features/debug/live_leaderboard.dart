import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D84: the two gift systems the ranking is split by. They never mix:
/// Attractiveness counts the gifts a user received, Wizard the lucky gifts
/// a user sent (CP-005 §9.1).
enum LiveViewersFilter {
  attraction(LevelCategory.attractiveness),
  wizard(LevelCategory.wizard);

  new(this.category);

  /// The level system whose emblem each row shows.
  final LevelCategory category;
}

/// One user of the preview room (labelled test data).
@immutable
class LiveViewerPreview {
  const new({
    required this.name,
    required this.username,
    required this.country,
    required this.support,
    required this.attraction,
    required this.wizard,
    required this.levels,
    this.photo,
  });

  final String name;
  final String username;

  /// ISO 3166-1 alpha-2 code (the flag).
  final String country;
  final String? photo;

  /// Coins sent in this room as normal gifts (the header's top three).
  final int support;

  /// Attractiveness and Wizard points in the period (ranking test data).
  final int attraction;
  final int wizard;
  final Map<LevelCategory, int> levels;

  int valueFor(LiveViewersFilter f) => switch (f) {
    LiveViewersFilter.attraction => attraction,
    LiveViewersFilter.wizard => wizard,
  };
}

/// Test users of the preview room (never shown in production).
List<LiveViewerPreview> liveViewersFixture({required bool ar}) {
  String n(String a, String e) => ar ? '$a (تجربة)' : '$e (test)';
  LiveViewerPreview v(
    String a,
    String e,
    String country,
    int support,
    int attraction,
    int wizard,
    int levelA,
    int levelW, [
    String? photo,
  ]) => LiveViewerPreview(
    name: n(a, e),
    username: 'test_${e.toLowerCase()}',
    country: country,
    photo: photo,
    support: support,
    attraction: attraction,
    wizard: wizard,
    levels: {
      LevelCategory.attractiveness: levelA,
      LevelCategory.support: (levelA + levelW) ~/ 2,
      LevelCategory.wizard: levelW,
    },
  );
  return [
    v('هدى', 'Huda', 'JO', 48200, 2500000, 31000, 88, 22, PreviewPhotos.huda),
    v('ليلى', 'Layla', 'SA', 1250, 1800000, 76000, 74, 18, PreviewPhotos.layla),
    v('رانيا', 'Rania', 'EG', 4100, 1200000, 9000, 61, 4, PreviewPhotos.rania),
    v('عمر', 'Omar', 'IQ', 21900, 856400, 154000, 52, 45, PreviewPhotos.omar),
    v('كريم', 'Karim', 'MA', 9800, 642100, 520000, 47, 71, PreviewPhotos.karim),
    v('سامي', 'Sami', 'EG', 300, 520700, 12000, 40, 9),
    v('نور', 'Nour', 'SA', 2200, 412300, 288000, 33, 52),
    v('دانة', 'Dana', 'SY', 800, 321900, 64000, 27, 21),
    v('رنا', 'Rana', 'AE', 650, 287400, 3000, 21, 3),
    v('مزن', 'Muzn', 'KW', 120, 201600, 41000, 14, 16),
  ];
}

/// D84/D85: the ranking periods, hour first. The viewers' ranking shows
/// [viewerPeriods]; the hosts' ranking list shows [hostPeriods].
enum LiveRankingPeriod {
  hourly(1, Duration(minutes: 5, seconds: 50)),
  daily(6, Duration(hours: 7, minutes: 12)),
  weekly(30, Duration(days: 3, hours: 4)),
  monthly(110, Duration(days: 12, hours: 6)),

  /// All time: never ends, so it has no countdown.
  overall(400, null);

  new(this.scale, this.fixtureRemaining);

  static const List<LiveRankingPeriod> viewerPeriods = [
    hourly,
    daily,
    weekly,
    monthly,
  ];
  static const List<LiveRankingPeriod> hostPeriods = [
    hourly,
    daily,
    monthly,
    overall,
  ];

  /// Test data only: how much more a longer period adds up to.
  final int scale;

  /// Test data only: the time left in the preview's current round. A real
  /// ranking takes its end time from the server.
  final Duration? fixtureRemaining;
}

/// The flag emoji of an ISO 3166-1 alpha-2 [code].
String countryFlag(String code) => String.fromCharCodes([
  for (final unit in code.toUpperCase().codeUnits) 0x1F1E6 + unit - 0x41,
]);

/// D84 tokens, measured from the owner's reference (941 px wide; kept
/// outside git). The leaderboard is always dark.
abstract final class KLeaderboard {
  /// Reference pixels → logical pixels for a [width]-wide board.
  static double scale(double width) => width / 941;

  static const Color ground = Color(0xFF070203);
  static const Color barTrack = Color(0xFF2D1B1D);
  static const Color barSelected = Color(0xFFFEEAEA);
  static const Color red = Color(0xFFE70F2C);
  static const Color redDeep = Color(0xFFB0061A);
  static const Color redText = Color(0xFFE0102A);
  static const Color chip = Color(0xFF151010);
  static const Color row = Color(0xFF151515);
  static const Color rowHighlight = Color(0xFF5C0C17);
  static const Color separator = Color(0x33FFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color muted = Color(0xB3FFFFFF);

  /// The metal of ranks 1–3 (score pills and glows).
  static const List<Color> metals = [
    Color(0xFFF2B33D),
    Color(0xFFD9DEE6),
    Color(0xFFD9895A),
  ];
}

/// D84 art (Kabso's own, AI-generated for this board; see the board entry).
abstract final class LeaderboardArt {
  static const String _p = 'assets/leaderboard';
  static const String background = '$_p/background.webp';
  static const String heart = '$_p/heart.webp';
  static const String wizardHat = '$_p/wizard_hat.webp';
  static String frame(int rank) => '$_p/podium_frame_$rank.webp';
  static String base(int rank) => '$_p/podium_base_$rank.webp';
  static String shield(int rank) => '$_p/rank_shield_$rank.webp';

  /// Noto Color Emoji flags (OFL; `assets/flags/NOTICE.txt`).
  static String flag(String country) =>
      'assets/flags/${country.toLowerCase()}.webp';
}

Widget _art(String asset, {double? width, double? height, BoxFit? fit}) =>
    Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      excludeFromSemantics: true,
      // A missing file must not break the board.
      errorBuilder: (_, _, _) => SizedBox(width: width, height: height),
    );

TextStyle _strong(
  BuildContext context,
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w700,
}) => context.textStyles.bodyStrong.copyWith(
  fontSize: size,
  height: 1.2,
  fontWeight: weight,
  color: color ?? KLeaderboard.white,
);

/// The four periods in one rounded track; the selected one is a pale pill
/// with red text. Hour first, at the reading start.
class LeaderboardPeriodBar extends StatelessWidget {
  const new({
    required this.selected,
    required this.onSelect,
    super.key,
    this.periods = LiveRankingPeriod.viewerPeriods,
  });

  final LiveRankingPeriod selected;
  final List<LiveRankingPeriod> periods;
  final ValueChanged<LiveRankingPeriod> onSelect;

  static Key periodKey(LiveRankingPeriod p) =>
      Key('leaderboard.period.${p.name}');

  static String label(AppLocalizations l10n, LiveRankingPeriod p) =>
      switch (p) {
        LiveRankingPeriod.hourly => l10n.livePeriodHourly,
        LiveRankingPeriod.daily => l10n.livePeriodDaily,
        LiveRankingPeriod.weekly => l10n.livePeriodWeekly,
        LiveRankingPeriod.monthly => l10n.livePeriodMonthly,
        LiveRankingPeriod.overall => l10n.livePeriodOverall,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 32 high as measured; the row keeps 40 for touch.
    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2427), KLeaderboard.barTrack, Color(0xFF1E1213)],
        ),
        border: Border.all(color: const Color(0x40FF5A6A), width: 0.8),
      ),
      child: Row(
        children: [
          for (var i = 0; i < periods.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 16,
                color: periods[i] == selected || periods[i - 1] == selected
                    ? Colors.transparent
                    : KLeaderboard.separator,
              ),
            Expanded(
              child: Semantics(
                button: true,
                selected: periods[i] == selected,
                child: InkWell(
                  key: periodKey(periods[i]),
                  onTap: () => onSelect(periods[i]),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  child: AnimatedContainer(
                    duration: KMotion.of(context, KMotion.fast),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(KRadius.pill),
                      gradient: periods[i] == selected
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, KLeaderboard.barSelected],
                            )
                          : null,
                      boxShadow: periods[i] == selected
                          ? const [
                              BoxShadow(
                                color: Color(0x80FF2E45),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          label(l10n, periods[i]),
                          maxLines: 1,
                          style: _strong(
                            context,
                            14,
                            weight: periods[i] == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: periods[i] == selected
                                ? KLeaderboard.redText
                                : KLeaderboard.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The gift filter button and the two gift systems (the selected one is
/// bright crimson with a glow).
class LeaderboardGiftFilters extends StatelessWidget {
  const new({
    required this.selected,
    required this.onSelect,
    required this.onFilter,
    super.key,
  });

  final LiveViewersFilter selected;
  final ValueChanged<LiveViewersFilter> onSelect;
  final VoidCallback onFilter;

  static const filterButtonKey = Key('leaderboard.giftFilter');
  static Key categoryKey(LiveViewersFilter f) =>
      Key('leaderboard.category.${f.name}');

  static String label(AppLocalizations l10n, LiveViewersFilter f) =>
      switch (f) {
        LiveViewersFilter.attraction => l10n.liveGiftsAttraction,
        LiveViewersFilter.wizard => l10n.liveGiftsWizard,
      };

  static Widget icon(LiveViewersFilter f, double size) => switch (f) {
    LiveViewersFilter.attraction => _art(
      LeaderboardArt.heart,
      width: size,
      height: size,
    ),
    LiveViewersFilter.wizard => _art(
      LeaderboardArt.wizardHat,
      width: size,
      height: size,
    ),
  };

  /// The art at a row's end: the gift box for gifts received, the hat
  /// for lucky gifts.
  static Widget rowIcon(LiveViewersFilter f, double size) => switch (f) {
    LiveViewersFilter.attraction => KabsoArtIcon(KabsoArt.giftBox, size: size),
    LiveViewersFilter.wizard => _art(
      LeaderboardArt.wizardHat,
      width: size,
      height: size,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            flex: 231,
            child: _GiftChip(
              key: filterButtonKey,
              label: l10n.liveGiftFilter,
              icon: const Icon(
                Icons.filter_alt_outlined,
                color: KLeaderboard.white,
                size: 18,
              ),
              selected: false,
              onTap: onFilter,
            ),
          ),
          const SizedBox(width: 6),
          for (final f in LiveViewersFilter.values) ...[
            if (f != LiveViewersFilter.values.first) const SizedBox(width: 6),
            Expanded(
              flex: f == LiveViewersFilter.attraction ? 325 : 273,
              child: _GiftChip(
                key: categoryKey(f),
                label: label(l10n, f),
                icon: icon(f, 22),
                selected: f == selected,
                onTap: () => onSelect(f),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GiftChip extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.pill),
        child: Center(
          child: AnimatedContainer(
            duration: KMotion.of(context, KMotion.fast),
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.pill),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? const [
                        Color(0xFFFF3348),
                        KLeaderboard.red,
                        Color(0xFFC4041B),
                      ]
                    : const [Color(0xFF2A2222), KLeaderboard.chip],
              ),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFF6B7A)
                    : const Color(0x99D02747),
                width: selected ? 1.2 : 0.8,
              ),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0x99FF1030), blurRadius: 14)]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: _strong(
                        context,
                        12.5,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                icon,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The time left in the period's round, counted down to [endsAt], between
/// the previous and next period, with the explanation at the start.
class LeaderboardCountdown extends StatefulWidget {
  const new({
    required this.endsAt,
    required this.onPrevious,
    required this.onNext,
    required this.onInfo,
    super.key,
    this.now = DateTime.now,
  });

  /// Null for a period that never ends (all time): no countdown.
  final DateTime? endsAt;

  /// Null when there is no previous / next period.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onInfo;
  final DateTime Function() now;

  static const valueKey = Key('leaderboard.countdown');
  static const previousKey = Key('leaderboard.previous');
  static const nextKey = Key('leaderboard.next');
  static const infoKey = Key('leaderboard.info');

  /// "05M 50S", "07H 12M", "03D 04H" (units as in the owner's reference).
  static String format(Duration left) {
    final d = left.isNegative ? Duration.zero : left;
    String two(int v) => v.toString().padLeft(2, '0');
    if (d.inDays > 0) return '${two(d.inDays)}D ${two(d.inHours % 24)}H';
    if (d.inHours > 0) return '${two(d.inHours)}H ${two(d.inMinutes % 60)}M';
    return '${two(d.inMinutes)}M ${two(d.inSeconds % 60)}S';
  }

  @override
  State<LeaderboardCountdown> createState() => _LeaderboardCountdownState();
}

class _LeaderboardCountdownState extends State<LeaderboardCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final endsAt = widget.endsAt;
    // Each chevron points outward: toward the start for the previous
    // period, toward the end for the next one.
    Widget chevron(Key key, VoidCallback? onTap, {required bool start}) {
      final pointsLeft = start != rtl;
      return IconButton(
        key: key,
        tooltip: start ? l10n.livePeriodPrevious : l10n.livePeriodNext,
        onPressed: onTap,
        color: KLeaderboard.red,
        disabledColor: KLeaderboard.red.withValues(alpha: 0.3),
        icon: Icon(
          pointsLeft
              ? Icons.keyboard_double_arrow_left_rounded
              : Icons.keyboard_double_arrow_right_rounded,
          size: 26,
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              chevron(
                LeaderboardCountdown.previousKey,
                widget.onPrevious,
                start: true,
              ),
              const SizedBox(width: 22),
              const Icon(
                Icons.schedule_rounded,
                color: KLeaderboard.red,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    key: LeaderboardCountdown.valueKey,
                    TextSpan(
                      children: endsAt == null
                          ? [TextSpan(text: l10n.liveRankingAllTime)]
                          : [
                              TextSpan(text: '${l10n.liveCountdown} : '),
                              TextSpan(
                                text: KFormat.bidiIsolate(
                                  LeaderboardCountdown.format(
                                    endsAt.difference(widget.now()),
                                  ),
                                ),
                                style: const TextStyle(
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                    ),
                    maxLines: 1,
                    style: _strong(context, 15),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              chevron(
                LeaderboardCountdown.nextKey,
                widget.onNext,
                start: false,
              ),
            ],
          ),
          PositionedDirectional(
            start: 0,
            child: IconButton(
              key: LeaderboardCountdown.infoKey,
              tooltip: l10n.liveRankingHelp,
              onPressed: widget.onInfo,
              icon: const Icon(
                Icons.info_outline_rounded,
                color: KLeaderboard.muted,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A score: the glowing heart and the compact amount.
class LeaderboardScore extends StatelessWidget {
  const new({required this.value, super.key, this.size = 14});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The heart first in both languages; the amount in the reading
    // direction (so "2.5 مليون" reads right).
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1A35).withValues(alpha: 0.55),
                blurRadius: size * 0.8,
              ),
            ],
          ),
          child: _art(LeaderboardArt.heart, width: size * 1.5),
        ),
        SizedBox(width: size * 0.35),
        Text(
          KFormat.compact(value, context.l10n),
          maxLines: 1,
          style: _strong(context, size).copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The name and the flag, each its own element.
class _NameFlag extends StatelessWidget {
  const new({required this.viewer, required this.size, this.center = false});

  final LiveViewerPreview viewer;
  final double size;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      textDirection: TextDirection.ltr,
      children: [
        Flexible(
          child: Text(
            viewer.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _strong(context, size, weight: FontWeight.w500).copyWith(
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ),
        SizedBox(width: size * 0.6),
        Image.asset(
          LeaderboardArt.flag(viewer.country),
          width: size * 1.25,
          height: size * 0.94,
          excludeFromSemantics: true,
          // A country without art falls back to the emoji.
          errorBuilder: (_, _, _) => Text(
            countryFlag(viewer.country),
            style: TextStyle(fontSize: size),
          ),
        ),
      ],
    );
  }
}

/// The top three. Second on the left, first raised in the middle, third on
/// the right (as in the reference, in both languages). Each: a photo in its
/// winged, crowned metal frame, the rank shield, and a glass pedestal with
/// the name, flag and score.
class LeaderboardPodium extends StatelessWidget {
  const new({
    required this.top,
    required this.value,
    required this.onOpen,
    super.key,
  });

  final List<LiveViewerPreview> top;
  final int Function(LiveViewerPreview) value;
  final ValueChanged<LiveViewerPreview>? onOpen;

  static Key placeKey(int rank) => Key('leaderboard.podium.$rank');

  /// Geometry in reference pixels (941 wide), relative to the podium's top.
  /// Rank → (ring centre x, centre y, photo radius, frame width), pedestal
  /// (left, top, width, bottom), name row y, score y.
  static const _origin = 262.0;
  static const _height = 600.0;
  static const _ring = {
    1: (470.0, 470.0, 92.0, 379.0),
    2: (168.0, 560.0, 75.0, 326.0),
    3: (772.0, 585.0, 78.0, 345.0),
  };
  static const _pedestal = {
    1: (296.0, 548.0, 348.0, 862.0),
    2: (22.0, 598.0, 292.0, 838.0),
    3: (628.0, 612.0, 292.0, 852.0),
  };
  static const _text = {
    1: (660.0, 712.0),
    2: (700.0, 746.0),
    3: (716.0, 762.0),
  };
  static const Map<int, (double, double, double)> _frameHole = {
    1: (0.557, 0.243, 461 / 480),
    2: (0.554, 0.230, 415 / 480),
    3: (0.571, 0.226, 375 / 480),
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final k = KLeaderboard.scale(box.maxWidth);
        double y(double v) => (v - _origin) * k;
        final places = [for (var r = 1; r <= top.length && r <= 3; r++) r];
        Widget pedestal(int r) {
          final (l, t, w, b) = _pedestal[r]!;
          return Positioned(
            left: l * k,
            top: y(t),
            width: w * k,
            height: (b - t) * k,
            child: _art(LeaderboardArt.base(r), fit: BoxFit.fill),
          );
        }

        Widget frame(int r) {
          final v = top[r - 1];
          final (cx, cy, radius, fw) = _ring[r]!;
          final (holeY, _, aspect) = _frameHole[r]!;
          final fh = fw * aspect;
          final photo = (radius + 4) * 2 * k;
          return Positioned(
            left: (cx - fw / 2) * k,
            top: y(cy - holeY * fh),
            width: fw * k,
            height: fh * k,
            child: Stack(
              children: [
                Positioned(
                  left: (fw / 2) * k - photo / 2,
                  top: holeY * fh * k - photo / 2,
                  child: KAvatar(
                    name: v.name,
                    image: PreviewPhotos.asset(v.photo),
                    size: photo,
                  ),
                ),
                Positioned.fill(child: _art(LeaderboardArt.frame(r))),
              ],
            ),
          );
        }

        Widget shield(int r) {
          final (cx, cy, radius, _) = _ring[r]!;
          final w = (r == 1 ? 64.0 : 54.0) * k;
          final h = w * 155 / 128;
          return Positioned(
            left: cx * k - w / 2,
            top: y(cy + radius) - h * 0.28,
            width: w,
            height: h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _art(LeaderboardArt.shield(r))),
                Padding(
                  padding: EdgeInsets.only(bottom: h * 0.08),
                  child: Text(
                    '$r',
                    textDirection: TextDirection.ltr,
                    style: _strong(context, h * 0.48).copyWith(
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Color(0xAA000000), blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget label(int r) {
          final v = top[r - 1];
          final (l, _, w, _) = _pedestal[r]!;
          final (nameY, scoreY) = _text[r]!;
          final big = r == 1;
          return Positioned(
            left: (l + 10) * k,
            width: (w - 20) * k,
            top: y(nameY) - 12,
            child: Column(
              children: [
                SizedBox(
                  height: 22,
                  child: _NameFlag(
                    viewer: v,
                    size: big ? 14.5 : 13,
                    center: true,
                  ),
                ),
                SizedBox(height: math.max(2, (scoreY - nameY) * k - 22 + 4)),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 10, 2),
                  decoration: BoxDecoration(
                    color: const Color(0x8C000000),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    border: Border.all(
                      color: KLeaderboard.metals[r - 1].withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: LeaderboardScore(
                      value: value(v),
                      size: big ? 14 : 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget tap(int r) {
          final (l, _, w, b) = _pedestal[r]!;
          final (_, cy, radius, _) = _ring[r]!;
          final v = top[r - 1];
          return Positioned(
            key: placeKey(r),
            left: l * k,
            width: w * k,
            top: y(cy - radius),
            height: (b - cy + radius) * k,
            child: Semantics(
              button: true,
              label: '$r. ${v.name}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpen == null ? null : () => onOpen!(v),
              ),
            ),
          );
        }

        // Paint order: the sides behind the first, pedestals behind frames.
        final order = [
          for (final r in const [2, 3, 1])
            if (places.contains(r)) r,
        ];
        return Directionality(
          textDirection: Directionality.of(context),
          child: SizedBox(
            height: _height * k,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The stage glow under the pedestals.
                Positioned(
                  left: 0,
                  right: 0,
                  top: y(700),
                  height: 170 * k,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [Color(0x99D0101F), Color(0x00D0101F)],
                      ),
                    ),
                  ),
                ),
                for (final r in order) ...[
                  pedestal(r),
                  label(r),
                  frame(r),
                  shield(r),
                ],
                for (final r in order) tap(r),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A rank from 4 on. Same order as the reference in both languages: rank,
/// photo, level emblem, name and flag, then the score, the gift system's
/// art and a chevron.
class LeaderboardRow extends StatelessWidget {
  const new({
    required this.rank,
    required this.viewer,
    required this.value,
    required this.filter,
    required this.highlight,
    required this.onOpen,
    super.key,
  });

  final int rank;
  final LiveViewerPreview viewer;
  final int value;
  final LiveViewersFilter filter;

  /// The first row under the podium glows crimson.
  final bool highlight;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final level = viewer.levels[filter.category];
    return Semantics(
      button: true,
      label: '$rank. ${viewer.name}',
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(vertical: 1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: highlight
                ? const [Color(0xFF6E1020), KLeaderboard.rowHighlight]
                : const [Color(0xFF1B1B1B), KLeaderboard.row],
          ),
          border: Border.all(
            color: highlight
                ? const Color(0xFFB21A2E)
                : const Color(0x14FFFFFF),
            width: highlight ? 1 : 0.6,
          ),
          boxShadow: highlight
              ? const [BoxShadow(color: Color(0x66C0101F), blurRadius: 10)]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(9),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: _strong(context, 14, weight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 2),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xCCE0485A)),
                  ),
                  child: KAvatar(
                    name: viewer.name,
                    image: PreviewPhotos.asset(viewer.photo),
                    size: 34,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 26,
                  child: level == null
                      ? null
                      : KLevelEmblem(
                          category: filter.category,
                          tier: KLevelArt.tier(level),
                          size: 24,
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(child: _NameFlag(viewer: viewer, size: 13)),
                const SizedBox(width: 6),
                // The score keeps its size; with large text it shrinks
                // before it can push the row out.
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: LeaderboardScore(value: value, size: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                LeaderboardGiftFilters.rowIcon(filter, 22),
                const SizedBox(width: 2),
                // Points right in both languages, as in the reference.
                const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: KLeaderboard.muted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The leaderboard body under the sheet's tabs: periods, gift systems,
/// countdown, podium and ranks 4–10, on the dark crimson stage.
class LiveLeaderboard extends StatelessWidget {
  const new({
    required this.viewers,
    required this.period,
    required this.filter,
    required this.endsAt,
    required this.onPeriod,
    required this.onFilter,
    required this.onGiftFilter,
    required this.onInfo,
    required this.onOpen,
    super.key,
    this.now = DateTime.now,
    this.maxRows = 10,
    this.periods = LiveRankingPeriod.viewerPeriods,
    this.showGiftFilters = true,
    this.valueOf,
  });

  final List<LiveViewerPreview> viewers;
  final LiveRankingPeriod period;
  final LiveViewersFilter filter;
  final DateTime? endsAt;

  /// The period bar's periods (and the chevrons' steps).
  final List<LiveRankingPeriod> periods;

  /// D85: the hosts' list ranks by gifts received only, without the row.
  final bool showGiftFilters;

  /// The score of a user in [period]; by default the filter's test value
  /// scaled by the period.
  final int Function(LiveViewerPreview user, LiveRankingPeriod period)? valueOf;
  final ValueChanged<LiveRankingPeriod> onPeriod;
  final ValueChanged<LiveViewersFilter> onFilter;
  final VoidCallback onGiftFilter;
  final VoidCallback onInfo;
  final ValueChanged<LiveViewerPreview>? onOpen;
  final DateTime Function() now;
  final int maxRows;

  static Key rowKey(int rank) => Key('leaderboard.row.$rank');

  int _value(LiveViewerPreview v) =>
      valueOf?.call(v, period) ?? v.valueFor(filter) * period.scale;

  @override
  Widget build(BuildContext context) {
    final ranked = [
      for (final v in viewers)
        if (_value(v) > 0) v,
    ]..sort((a, b) => _value(b).compareTo(_value(a)));
    final shown = ranked.take(maxRows).toList();
    final i = periods.indexOf(period);
    return DecoratedBox(
      decoration: const BoxDecoration(color: KLeaderboard.ground),
      child: Stack(
        children: [
          Positioned.fill(
            child: _art(LeaderboardArt.background, fit: BoxFit.cover),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 2, 26, 0),
                child: LeaderboardPeriodBar(
                  selected: period,
                  onSelect: onPeriod,
                  periods: periods,
                ),
              ),
              if (showGiftFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: LeaderboardGiftFilters(
                    selected: filter,
                    onSelect: onFilter,
                    onFilter: onGiftFilter,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LeaderboardCountdown(
                  // A new period restarts the count.
                  key: ValueKey(period),
                  endsAt: endsAt,
                  now: now,
                  onPrevious: i > 0 ? () => onPeriod(periods[i - 1]) : null,
                  onNext: i < periods.length - 1
                      ? () => onPeriod(periods[i + 1])
                      : null,
                  onInfo: onInfo,
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? KEmptyState(
                        icon: Icons.card_giftcard_rounded,
                        title: context.l10n.liveRankingEmpty,
                        message: '',
                        compact: true,
                      )
                    // Built lazily: the hosts' list shows up to 100.
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        itemCount: 1 + math.max(0, shown.length - 3),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return LeaderboardPodium(
                              top: shown.take(3).toList(),
                              value: _value,
                              onOpen: onOpen,
                            );
                          }
                          final r = index + 3;
                          final v = shown[r - 1];
                          return LeaderboardRow(
                            key: rowKey(r),
                            rank: r,
                            viewer: v,
                            value: _value(v),
                            filter: filter,
                            highlight: r == 4,
                            onOpen: onOpen == null ? null : () => onOpen!(v),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
