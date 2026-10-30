import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D169 card geometry, measured on the owner's style reference (a
/// third-party membership-tier board, kept out of git; its medals and text
/// are not used). The board's card is 298 × 144 px; values here are scaled
/// to a 398-lp card (a 430-lp phone with 16-lp sides), M = measured on the
/// board, E = estimate.
abstract final class KLevelCard {
  /// Card height ÷ width (M 144 / 298); the card grows with its content.
  static const double aspect = 0.483;

  /// Corner radius (E 10 px → 13 lp).
  static const double radius = 13;

  /// Content insets: start M 17 px → 23 lp; top 30 lp (M 26 px to the
  /// title glyphs; the first overlay put ours 8 lp high); bottom 20 lp
  /// (M 13 px → 17, plus the overlay's 3 lp); end M 20 px.
  static const EdgeInsetsDirectional padding = EdgeInsetsDirectional.fromSTEB(
    22,
    30,
    18,
    20,
  );

  /// Title → line (M 4 px → 5 lp) and line → bar (M 9 px → 12 lp; the
  /// first overlay put the bar 23 lp high with 8, so 16).
  static const double lineGap = 5;
  static const double barGap = 16;

  /// The medal box: M 110 × 102 px art → 0.37 of the card width, its end
  /// edge 7 lp inside the card end (M 5 px) and rising 28 lp above the card
  /// top (M 21 px). Kabso's emblems are square, so the box is square.
  static const double medalFactor = 0.36;
  static const double medalMin = 104;
  static const double medalMax = 150;
  static const double medalEnd = 6;
  static const double medalRise = 28;

  /// The progress bar: 0.57 of the card wide (M 169 / 298 px), 4 lp high
  /// (M 3 px).
  static const double barFactor = 0.57;
  static const double barHeight = 4;

  /// Type (E, from the board's glyph heights × 1.336): title 19 bold, the
  /// line under it 13, the bottom line 12.5, the button 13 bold.
  static const double titleSize = 19;
  static const double lineSize = 13;
  static const double footSize = 12.5;

  /// The dark pill button (M 72 × 26 px → 96 × 35 lp; #12073F).
  static const double buttonHeight = 35;
  static const Color button = Color(0xFF14093F);

  /// The highlighted number in the detail header's "Need X" line.
  static const Color highlight = Color(0xFFB0186A);

  /// The medal's size on a card [width] wide.
  static double medalFor(double width) =>
      (width * medalFactor).clamp(medalMin, medalMax);
}

/// The pastel tint of a category card: its badge's gem colour washed
/// towards white (lighter at the top start, like the board's glass), or a
/// neutral grey while the category is inactive.
@immutable
class LevelCardTint {
  const new(this.gem, {required this.active});

  final Color gem;
  final bool active;

  Color get _base => active ? gem : const Color(0xFF9AA0B4);

  Color get light => Color.lerp(_base, Colors.white, 0.9)!;
  Color get mid => Color.lerp(_base, Colors.white, 0.8)!;
  Color get deep => Color.lerp(_base, Colors.white, 0.68)!;

  /// Text on the card: the gem darkened almost to black.
  Color get ink => Color.lerp(_base, const Color(0xFF0E0A24), 0.82)!;
  Color get inkSoft => ink.withValues(alpha: 0.68);

  Color get track => _base.withValues(alpha: 0.16);
}

/// D169: one level category as a soft glass card tinted to its badge: the
/// badge large over the card's top end, the category's name in bold, a
/// line under it, a thin progress bar, and a bottom line with a dark pill
/// button. Everything comes from the server's `LevelSummary`; an inactive
/// category says «غير مفعّل بعد» with its explanation and no bar.
///
/// [header] = the detail page's version: the level's name and number as
/// the title, the points under it, a wider bar and "Need X experience to
/// the next level" at the bottom, with no button.
class LevelCategoryCard extends StatelessWidget {
  const new({
    required this.summary,
    super.key,
    this.onOpen,
    this.header = false,
  });

  final LevelSummary summary;

  /// Opens the category's page (the card and its button); null = no button.
  final VoidCallback? onOpen;
  final bool header;

  static const buttonKey = Key('levels.card.details');
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
    final tint = LevelCardTint(
      KLevelArt.gemOf(s.category, tier),
      active: s.available,
    );
    final points = l10n.levelsPoints(formatPoints(s.points));
    final levelLine = level == null
        ? null
        : '${level.name} · ${l10n.levelsLevelNumber(level.levelNumber)}';

    final String title;
    final String line;
    final String? foot;
    if (!s.available) {
      title = s.name;
      line = l10n.levelsUnavailable;
      foot = s.description;
    } else if (header) {
      title = levelLine ?? s.name;
      line = level == null ? l10n.levelsNoLevel : points;
      foot = null; // the "Need X" line below
    } else {
      title = s.name;
      line = s.maxLevel
          ? l10n.levelsMax
          : s.pointsToNext == null
          ? (level == null ? l10n.levelsNoLevel : points)
          : s.nextLevel == null
          ? l10n.levelsToNext(formatPoints(s.pointsToNext!))
          : l10n.levelsToNamed(
              formatPoints(s.pointsToNext!),
              s.nextLevel!.name,
            );
      foot = levelLine == null ? points : '$levelLine · $points';
    }
    final needX = header && s.available && !s.maxLevel && s.pointsToNext != null
        ? formatPoints(s.pointsToNext!)
        : null;

    final semantics = [
      s.name,
      if (!s.available) l10n.levelsUnavailable,
      ?levelLine,
      if (s.available) points,
      if (s.available && s.maxLevel) l10n.levelsMax,
      if (s.available && !s.maxLevel && s.pointsToNext != null)
        l10n.levelsToNext(formatPoints(s.pointsToNext!)),
      if (!s.available) s.description,
    ].join('، ');

    return Semantics(
      container: true,
      button: onOpen != null,
      onTap: onOpen,
      label: semantics,
      excludeSemantics: onOpen == null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final medal = KLevelCard.medalFor(w) * (header ? 1.15 : 1);
          final textEnd = medal + KLevelCard.medalEnd;
          return Padding(
            padding: const EdgeInsetsDirectional.only(
              top: KLevelCard.medalRise,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _Glass(
                  tint: tint,
                  onTap: onOpen,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: w * KLevelCard.aspect,
                    ),
                    // Intrinsic height so the bottom row sits at the card's
                    // bottom when the content is shorter than the card.
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: KLevelCard.padding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsetsDirectional.only(
                                end: textEnd - KLevelCard.padding.end,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textStyles.title.copyWith(
                                      fontSize: KLevelCard.titleSize,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                      color: tint.ink,
                                    ),
                                  ),
                                  const SizedBox(height: KLevelCard.lineGap),
                                  Text(
                                    line,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textStyles.body.copyWith(
                                      fontSize: KLevelCard.lineSize,
                                      height: 1.3,
                                      color: tint.inkSoft,
                                      fontWeight: s.available
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (s.available) ...[
                              const SizedBox(height: KLevelCard.barGap),
                              FractionallySizedBox(
                                widthFactor: header
                                    ? 0.62
                                    : KLevelCard.barFactor,
                                alignment: AlignmentDirectional.centerStart,
                                child: _Bar(
                                  percent: s.maxLevel
                                      ? 100
                                      : s.progressPercent ?? 0,
                                  tint: tint,
                                ),
                              ),
                            ],
                            const SizedBox(height: KSpacing.lg),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: header && s.available
                                      ? _NeedLine(
                                          key: needKey,
                                          text: s.maxLevel
                                              ? l10n.levelsMax
                                              : needX == null
                                              ? ''
                                              : l10n.levelsNeedXp(needX),
                                          x: needX,
                                          color: tint.inkSoft,
                                        )
                                      : Text(
                                          foot ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.textStyles.caption
                                              .copyWith(
                                                fontSize: KLevelCard.footSize,
                                                height: 1.35,
                                                color: tint.inkSoft,
                                              ),
                                        ),
                                ),
                                if (onOpen != null) ...[
                                  const SizedBox(width: KSpacing.sm),
                                  _DetailsButton(onTap: onOpen!),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // The badge over the card's top end; the art never mirrors.
                PositionedDirectional(
                  end: KLevelCard.medalEnd,
                  top: -KLevelCard.medalRise,
                  child: Container(
                    key: medalKey,
                    width: medal,
                    height: medal,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(
                            alpha: s.available ? 0.55 : 0,
                          ),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: KLevelEmblem(
                      category: s.category,
                      tier: tier,
                      size: medal,
                      dimmed: !s.available,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const new({required this.tint, required this.child, this.onTap});

  final LevelCardTint tint;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KLevelCard.radius),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: [
          BoxShadow(
            color: tint.deep.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [tint.light, tint.mid, tint.deep],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            // The board's diagonal glass sheen.
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.2, -1),
                end: const Alignment(0.6, 1),
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.38),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.percent, required this.tint});

  final double percent;
  final LevelCardTint tint;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(KRadius.pill),
    child: SizedBox(
      height: KLevelCard.barHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: tint.track),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: (percent / 100).clamp(0, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KRadius.pill),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [tint.gem.withValues(alpha: 0.75), tint.gem],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailsButton extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: LevelCategoryCard.buttonKey,
    color: KLevelCard.button,
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KLevelCard.buttonHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KSpacing.lg + 2,
            vertical: KSpacing.xs,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              context.l10n.levelsDetails,
              style: context.textStyles.bodyStrong.copyWith(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Need X experience to the next level" with X stressed; X is isolated
/// left-to-right so its digits keep their order in the Arabic sentence.
class _NeedLine extends StatelessWidget {
  const new({
    required this.text,
    required this.x,
    required this.color,
    super.key,
  });

  final String text;
  final String? x;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final at = x == null ? -1 : text.indexOf(x!);
    return Text.rich(
      TextSpan(
        children: at < 0
            ? [TextSpan(text: text)]
            : [
                TextSpan(text: text.substring(0, at)),
                TextSpan(
                  text: '\u2066$x\u2069',
                  style: const TextStyle(
                    color: KLevelCard.highlight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: text.substring(at + x!.length)),
              ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: context.textStyles.caption.copyWith(
        fontSize: KLevelCard.lineSize,
        height: 1.35,
        color: color,
      ),
    );
  }
}
