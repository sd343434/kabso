import 'dart:math' as math;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D169 card geometry, measured on the owner's style reference (a
/// third-party membership-tier board, 736 × 981 px, kept out of git; its
/// medals and text are not used). Its first card is 298 × 142 px; every
/// value is a share of the card's width W so one card scales from the
/// two-column grid (≈ 184 lp at 430 lp) to the full-width header. M =
/// measured on the board, E = estimate; type has a legibility floor.
abstract final class KLevelCard {
  /// Height ÷ width (M 142 / 298); the card grows with its content.
  static const double aspect = 0.477;

  /// Corner radius (M ≈ 10 px → 0.034 W, at least 10 lp).
  static double radius(double w) => math.max(10, w * 0.034);

  /// Content start inset (M 17 px), top inset to the title's line box
  /// (M 25 px to the glyphs), end inset (M 20 px), bottom (M 13 px).
  static double start(double w) => w * 0.057;
  static double top(double w) => w * 0.062;
  static double end(double w) => w * 0.067;
  static double bottom(double w) => w * 0.044;

  /// Type: title (M 17-px glyphs → ≈ 0.074 W), the grey line and the
  /// caption (M 9-px glyphs → ≈ 0.042 W), the pill's label; floors keep
  /// them legible on the 151-lp cards of a 360-lp phone.
  static double title(double w) => (w * 0.074).clamp(12.5, 22);
  static double line(double w) => (w * 0.042).clamp(10.5, 14);
  static double pillText(double w) => (w * 0.04).clamp(10.5, 13);

  /// Title → line (M 11 px), line → bar (M 10 px).
  static double titleGap(double w) => w * 0.012;
  static double barGap(double w) => w * 0.03;

  /// The bar: 0.57 W long (M 170 / 298 px), M 3–4 px thick.
  static const double barFactor = 0.57;
  static double barHeight(double w) => math.max(3, w * 0.012);

  /// The pill (M 72 × 26 px, #12073F, white bold label).
  static double pillHeight(double w) => math.max(22, w * 0.087);
  static double pillPad(double w) => math.max(9, w * 0.05);
  static const Color pill = Color(0xFF12073F);

  /// The badge: M 110 px wide (0.37 W), its end 5 px inside the card's end
  /// (0.017 W), rising 22 px above the card's top (0.074 W).
  static double medal(double w) => w * 0.37;
  static double medalEnd(double w) => w * 0.017;
  static double medalRise(double w) => w * 0.074;

  /// The board's panel behind the grid (M #14006C) and its insets: M 12 px
  /// around the cards and 25 px between the columns (as shares of W).
  static const Color panel = Color(0xFF14006C);
  static const double panelPadFactor = 0.04;
  static const double columnGapFactor = 0.084;

  /// Card text (M: titles #24124F-like navy, lines #6E6880 grey).
  static const Color ink = Color(0xFF1F1147);
  static const Color grey = Color(0xFF6C6683);

  /// The stressed number in "Need X experience to the next level".
  static const Color highlight = Color(0xFFB0186A);
}

/// The card's tint from its badge's dominant colour, as strong as the
/// board's (M per card: top start ≈ 88 % white, middle ≈ 70 %, a white
/// sheen along the bottom, the bottom end corner ≈ 45 %).
@immutable
class LevelCardTint {
  const new(this.gem);

  final Color gem;

  Color _wash(double t) => Color.lerp(gem, Colors.white, t)!;

  List<Color> get colors => [_wash(0.9), _wash(0.72), _wash(0.84), _wash(0.45)];
  static const List<double> stops = [0, 0.45, 0.72, 1];

  /// The bar's fill.
  Color get accent => Color.lerp(gem, Colors.black, 0.08)!;
  Color get track => Colors.white.withValues(alpha: 0.75);
}

/// What a card's pill says (non-interactive styling).
@immutable
class LevelCardPill {
  const new(this.label, {this.locked = false});

  final String label;
  final bool locked;
}

/// D169: one card of the reference's language — bold title at the top
/// start, a small grey line under it, a short thin bar, then at the bottom
/// a grey caption at the start and a dark pill at the end; the badge large
/// over the card's top end, breaking out of its top edge (top left in
/// Arabic; the art never mirrors). [locked] shows the card dimmed and
/// desaturated, still legible; [glow] lights the caller's tier.
class LevelTierCard extends StatelessWidget {
  const new({
    required this.category,
    required this.tier,
    required this.title,
    required this.line,
    required this.caption,
    required this.pill,
    super.key,
    this.progress,
    this.locked = false,
    this.frame,
    this.medalKey,
    this.lineKey,
    this.glow = false,
  });

  final LevelCategory category;
  final int tier;
  final String title;

  /// The grey line (may stress a number).
  final InlineSpan line;
  final String caption;
  final LevelCardPill pill;

  /// 0–1; null = no bar.
  final double? progress;
  final bool locked;

  /// The support tier's avatar frame shown before the caption.
  final String? frame;
  final Key? medalKey;
  final Key? lineKey;

  /// The tier the caller is on (D169, owner: «ولا تضيء إلا إذا كان الشخص
  /// على هذه الفئة»): a soft glow of the badge's colour around the card.
  final bool glow;

  /// Dim tiers (D169): 65 % desaturated and 15 % darker, still legible.
  static const _desaturate = ColorFilter.matrix([
    0.415, 0.3951, 0.0399, 0, 0, //
    0.1175, 0.6926, 0.0399, 0, 0,
    0.1175, 0.3951, 0.3374, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final tint = LevelCardTint(KLevelArt.gemOf(category, tier));
      final medal = KLevelCard.medal(w);
      final rise = KLevelCard.medalRise(w);
      final t = context.textStyles;
      final card = Padding(
        padding: EdgeInsetsDirectional.only(top: rise),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KLevelCard.radius(w)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: tint.colors,
                  stops: LevelCardTint.stops,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tint.gem.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  if (glow)
                    BoxShadow(
                      color: tint.gem.withValues(alpha: 0.75),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: w * KLevelCard.aspect),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      KLevelCard.start(w),
                      KLevelCard.top(w),
                      KLevelCard.end(w),
                      KLevelCard.bottom(w),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          // Title and line stop before the badge.
                          padding: EdgeInsetsDirectional.only(
                            end:
                                medal +
                                KLevelCard.medalEnd(w) -
                                KLevelCard.end(w),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  style: t.title.copyWith(
                                    fontSize: KLevelCard.title(w),
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: KLevelCard.ink,
                                  ),
                                ),
                              ),
                              SizedBox(height: KLevelCard.titleGap(w)),
                              Text.rich(
                                line,
                                key: lineKey,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption.copyWith(
                                  fontSize: KLevelCard.line(w),
                                  height: 1.3,
                                  color: KLevelCard.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (progress != null) ...[
                          SizedBox(height: KLevelCard.barGap(w)),
                          FractionallySizedBox(
                            widthFactor: KLevelCard.barFactor,
                            alignment: AlignmentDirectional.centerStart,
                            child: _Bar(
                              value: progress!,
                              tint: tint,
                              height: KLevelCard.barHeight(w),
                            ),
                          ),
                        ],
                        const Spacer(),
                        SizedBox(height: KLevelCard.barGap(w)),
                        Row(
                          children: [
                            if (frame case final f?) ...[
                              Image.asset(
                                f,
                                width: KLevelCard.pillHeight(w),
                                height: KLevelCard.pillHeight(w),
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                              const SizedBox(width: KSpacing.xxs),
                            ],
                            // One line like the board's caption: it scales
                            // down rather than wrapping beside the pill.
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  caption,
                                  maxLines: 1,
                                  style: t.caption.copyWith(
                                    fontSize: KLevelCard.line(w),
                                    height: 1.25,
                                    color: KLevelCard.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: KSpacing.xs),
                            _Pill(pill: pill, w: w),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: KLevelCard.medalEnd(w),
              top: -rise,
              child: SizedBox.square(
                key: medalKey,
                dimension: medal,
                child: KLevelEmblem(
                  category: category,
                  tier: tier,
                  size: medal,
                ),
              ),
            ),
          ],
        ),
      );
      return locked
          ? ColorFiltered(colorFilter: _desaturate, child: card)
          : card;
    },
  );
}

class _Bar extends StatelessWidget {
  const new({required this.value, required this.tint, required this.height});

  final double value;
  final LevelCardTint tint;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(KRadius.pill),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: tint.track),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tint.accent,
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const new({required this.pill, required this.w});

  final LevelCardPill pill;
  final double w;

  @override
  Widget build(BuildContext context) => Container(
    height: KLevelCard.pillHeight(w),
    padding: EdgeInsetsDirectional.symmetric(horizontal: KLevelCard.pillPad(w)),
    decoration: const ShapeDecoration(
      color: KLevelCard.pill,
      shape: StadiumBorder(),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pill.locked) ...[
          Icon(
            Icons.lock_rounded,
            size: KLevelCard.pillText(w),
            color: Colors.white,
          ),
          const SizedBox(width: 3),
        ],
        Text(
          pill.label,
          maxLines: 1,
          style: context.textStyles.bodyStrong.copyWith(
            fontSize: KLevelCard.pillText(w),
            height: 1.1,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// The category page's header (D169): the caller's current tier as a
/// full-width card in the same language — the level's name and number as
/// the title, "Need X experience to the next level" (X stressed and
/// bidi-isolated) as the line, the progress bar, the points as the caption
/// and «الحالي» in the pill. An inactive category says «غير مفعّل بعد»
/// with its explanation, no bar, greyed.
class LevelCategoryCard extends StatelessWidget {
  const new({required this.summary, super.key});

  final LevelSummary summary;

  static const medalKey = Key('levels.card.medal');
  static const needKey = Key('levels.card.need');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = summary;
    final level = s.available ? s.level : null;
    final tier = level == null
        ? 1
        : KLevelArt.tierOf(
            s.category,
            level.levelNumber,
            iconKey: level.iconKey,
          );
    final points = l10n.levelsPoints(formatPoints(s.points));
    final x = s.available && !s.maxLevel && s.pointsToNext != null
        ? formatPoints(s.pointsToNext!)
        : null;
    final String title;
    final InlineSpan line;
    if (!s.available) {
      title = '${s.name} · ${l10n.levelsUnavailable}';
      line = TextSpan(text: s.description);
    } else {
      title = level == null
          ? '${s.name} · ${l10n.levelsNoLevel}'
          : '${level.name} · ${l10n.levelsLv(level.levelNumber)}';
      line = s.maxLevel
          ? TextSpan(text: l10n.levelsMax)
          : x == null
          ? const TextSpan()
          : _stressed(l10n.levelsNeedXp(x), x);
    }
    return Semantics(
      container: true,
      label: [
        s.name,
        title,
        if (s.available) points,
        if (x != null) l10n.levelsNeedXp(x),
        if (s.available && s.maxLevel) l10n.levelsMax,
      ].join('، '),
      excludeSemantics: true,
      child: LevelTierCard(
        category: s.category,
        tier: tier,
        title: title,
        line: line,
        caption: s.available ? points : l10n.levelsUnavailableBody,
        pill: s.available
            ? LevelCardPill(l10n.levelsTierCurrent)
            : LevelCardPill(l10n.levelsTierLocked, locked: true),
        progress: s.available
            ? (s.maxLevel ? 1 : (s.progressPercent ?? 0) / 100)
            : null,
        locked: !s.available,
        frame:
            s.available && level != null && s.category == LevelCategory.support
            ? KLevelArt.supportFrame(tier)
            : null,
        medalKey: medalKey,
        lineKey: s.available ? needKey : null,
      ),
    );
  }
}

/// [text] with [x] stressed in the highlight colour and isolated
/// left-to-right, so its digits keep their order in Arabic.
InlineSpan _stressed(String text, String x) {
  final at = text.indexOf(x);
  if (at < 0) return TextSpan(text: text);
  return TextSpan(
    children: [
      TextSpan(text: text.substring(0, at)),
      TextSpan(
        text: '\u2066$x\u2069',
        style: const TextStyle(
          color: KLevelCard.highlight,
          fontWeight: FontWeight.w700,
        ),
      ),
      TextSpan(text: text.substring(at + x.length)),
    ],
  );
}

/// The stressed form of a line, for the tier cards' "X points to unlock" lines.
InlineSpan levelCardStressed(String text, String x) => _stressed(text, x);
