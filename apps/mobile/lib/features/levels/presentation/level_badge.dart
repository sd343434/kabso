import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's level art (kabso_levels pack, D72): per category 11 tiers of
/// 3D emblems (256×256 WebP) — levels 1–9, 10–19 … 90–99, and 100.
abstract final class KLevelArt {
  static const int tiers = 11;

  /// Per tier: gem colour, deep shade, frame metal (from the pack's
  /// `kabso_level_badge.dart`).
  static const List<List<Color>> tierColors = [
    [Color(0xFF958A80), Color(0xFF1E1915), Color(0xFF8E96A3)],
    [Color(0xFFE8901E), Color(0xFF341502), Color(0xFFC07A42)],
    [Color(0xFF68CBE6), Color(0xFF082E40), Color(0xFFBFC8D6)],
    [Color(0xFFA35CF0), Color(0xFF1C0838), Color(0xFFE7B23C)],
    [Color(0xFF22C46A), Color(0xFF032612), Color(0xFFA8D9DE)],
    [Color(0xFF3A7CFF), Color(0xFF06143C), Color(0xFFE7B23C)],
    [Color(0xFFF0479A), Color(0xFF36041C), Color(0xFFA8D9DE)],
    [Color(0xFF1FD2C0), Color(0xFF022C28), Color(0xFFE4A08C)],
    [Color(0xFFF0283C), Color(0xFF320006), Color(0xFFE7B23C)],
    [Color(0xFFCFE6FF), Color(0xFF2A3C5C), Color(0xFFA8D9DE)],
    [Color(0xFFFF3A2A), Color(0xFF3C0004), Color(0xFFF2A23A)],
  ];

  static final RegExp _iconKey = RegExp(r'^tier_(\d{2})$');

  /// The art tier (1–11) of a level: the server's `iconKey` when it names
  /// one (`tier_01`…`tier_11`), else from the level number as the pack
  /// draws it.
  static int tier(int levelNumber, {String? iconKey}) {
    final match = iconKey == null ? null : _iconKey.firstMatch(iconKey);
    final fromKey = match == null ? null : int.parse(match.group(1)!);
    if (fromKey != null && fromKey >= 1 && fromKey <= tiers) return fromKey;
    if (levelNumber >= 100) return tiers;
    return levelNumber.clamp(1, 99) ~/ 10 + 1;
  }

  /// D169: the owner's 21 support badges (2026-10-30,
  /// `assets/levels/support/`) replace the pack's 11 for Support.
  static const int supportTiers = 21;

  /// The support tier of a level — a default the owner can change: tiers
  /// 1–20 are levels 1–5, 6–10 … 96–99 and tier 21 is level 100 alone.
  /// The server's `iconKey` names the 11-tier pack, so Support ignores it.
  static int supportTier(int levelNumber) => levelNumber >= 100
      ? supportTiers
      : (levelNumber.clamp(1, 99) - 1) ~/ 5 + 1;

  /// How many art tiers [category] has.
  static int tiersOf(LevelCategory category) =>
      category == LevelCategory.support ? supportTiers : tiers;

  /// The art tier of [levelNumber] in [category].
  static int tierOf(
    LevelCategory category,
    int levelNumber, {
    String? iconKey,
  }) => category == LevelCategory.support
      ? supportTier(levelNumber)
      : tier(levelNumber, iconKey: iconKey);

  /// The first and last level drawn with [tier] in [category].
  static (int, int) levelRange(LevelCategory category, int tier) {
    if (category == LevelCategory.support) {
      if (tier >= supportTiers) return (100, 100);
      return (tier * 5 - 4, tier == supportTiers - 1 ? 99 : tier * 5);
    }
    if (tier <= 1) return (1, 9);
    if (tier >= tiers) return (100, 100);
    return ((tier - 1) * 10, (tier - 1) * 10 + 9);
  }

  static String _nn(int tier) => tier.toString().padLeft(2, '0');

  static String asset(LevelCategory category, int tier) =>
      category == LevelCategory.support
      ? 'assets/levels/support/support_${_nn(tier)}.webp'
      : 'assets/levels/${category.slug}_${_nn(tier)}.webp';

  /// The support badge on its level bar (the name pill, D169).
  static String supportPill(int tier) =>
      'assets/levels/support/support_pill_${_nn(tier)}.webp';

  /// D169: the owner's 20 support tier avatar frames
  /// (`assets/levels/support_frames/`, bag `AVATAR_FRAME` `support_frame_NN`,
  /// given by the server when the tier is reached). Tier 21 has no frame of
  /// its own and keeps frame 20 — a default the owner may change.
  static const int supportFrames = 20;

  /// The avatar frame that comes with support [tier].
  static String supportFrame(int tier) =>
      'assets/levels/support_frames/support_frame_${_nn(tier.clamp(1, supportFrames))}.webp';

  /// Width ÷ height of each support pill image (96 px high).
  static const List<double> supportPillAspect = [
    208 / 96, 209 / 96, 210 / 96, 208 / 96, 208 / 96, 195 / 96, 192 / 96, //
    197 / 96, 197 / 96, 192 / 96, 187 / 96, 188 / 96, 189 / 96, 193 / 96,
    186 / 96, 193 / 96, 192 / 96, 196 / 96, 196 / 96, 191 / 96, 239 / 96,
  ];

  /// The gem colour of each support badge (mean of the saturated pixels in
  /// the badge's centre; tier 5's blue stone on gold reads gold).
  static const List<Color> supportGems = [
    Color(0xFFBB6A23),
    Color(0xFFD11844),
    Color(0xFF214FDD),
    Color(0xFF13A968),
    Color(0xFFE2A12B),
    Color(0xFFBD40B9),
    Color(0xFF3EB142),
    Color(0xFF4B81C8),
    Color(0xFFEC3F92),
    Color(0xFFDE4217),
    Color(0xFF186DE9),
    Color(0xFFA337C6),
    Color(0xFF49B046),
    Color(0xFF307BD8),
    Color(0xFFE63889),
    Color(0xFFD53218),
    Color(0xFF861FEA),
    Color(0xFF4777C6),
    Color(0xFF2DB246),
    Color(0xFFDB3618),
    Color(0xFFD63B1B),
  ];

  /// The gem colour of [tier] (progress bars, level text).
  static Color gem(int tier) => tierColors[tier - 1][0];

  /// The gem colour of [tier] in [category].
  static Color gemOf(LevelCategory category, int tier) =>
      category == LevelCategory.support
      ? supportGems[tier.clamp(1, supportTiers) - 1]
      : gem(tier.clamp(1, tiers));

  /// [gem] lightened for text on dark and light surfaces alike (the early
  /// tiers' smoky and bronze gems are too dim for text as they are).
  static Color text(int tier) => Color.lerp(gem(tier), Colors.white, 0.3)!;

  /// The frame metal of [tier] (badge outline).
  static Color frame(int tier) => tierColors[tier - 1][2];
}

/// A category's emblem for [tier]. Decorative: the caller labels it.
/// [dimmed] shows it greyed (an unavailable category or a level not reached).
class KLevelEmblem extends StatelessWidget {
  const new({
    required this.category,
    required this.tier,
    super.key,
    this.size = KSizes.avatarMd,
    this.dimmed = false,
  });

  final LevelCategory category;
  final int tier;
  final double size;
  final bool dimmed;

  static const _greyscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 0.45, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      KLevelArt.asset(category, tier),
      width: size,
      height: size,
      excludeFromSemantics: true,
      // A missing file must not break the screen.
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
    );
    return ExcludeSemantics(
      child: dimmed
          ? ColorFiltered(colorFilter: _greyscale, child: image)
          : image,
    );
  }
}

/// The compact badge: the emblem with a bevelled pill carrying the level
/// number (the pack's `KabsoLevelBadge`, on Kabso type). The number is
/// Latin and left-to-right in both languages; the emblem sits at the
/// reading start.
class KLevelBadge extends StatelessWidget {
  const new({
    required this.category,
    required this.levelNumber,
    super.key,
    this.iconKey,
    this.height = KMetrics.badgeHeight,
  });

  final LevelCategory category;
  final int levelNumber;
  final String? iconKey;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (category == LevelCategory.support) {
      return _SupportPill(levelNumber: levelNumber, height: height);
    }
    final tier = KLevelArt.tier(levelNumber, iconKey: iconKey);
    final c = KLevelArt.tierColors[tier - 1];
    final h = height;
    return SizedBox(
      height: h * 1.5,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.centerStart,
        children: [
          Container(
            margin: EdgeInsetsDirectional.only(start: h * 0.6),
            padding: EdgeInsetsDirectional.only(start: h * 0.75, end: h * 0.55),
            height: h,
            decoration: ShapeDecoration(
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.circular(h * 0.32),
                side: BorderSide(color: c[2], width: h * 0.09),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(c[0], c[1], 0.35)!,
                  Color.lerp(c[0], c[1], 0.65)!,
                  c[1],
                ],
              ),
            ),
            // Hugs the number (an aligned Container would fill the width).
            child: Center(
              widthFactor: 1,
              child: Text(
                '$levelNumber',
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: KFonts.latin,
                  fontSize: h * 0.68,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  shadows: [Shadow(color: c[1], offset: const Offset(0, 1))],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            child: KLevelEmblem(category: category, tier: tier, size: h * 1.5),
          ),
        ],
      ),
    );
  }
}

/// D169: the support level next to a name — the owner's badge on its
/// coloured bar for the level's tier, with the number on the bar. The art
/// and the number never mirror (Latin, left to right in both languages).
class _SupportPill extends StatelessWidget {
  const new({required this.levelNumber, required this.height});

  final int levelNumber;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tier = KLevelArt.supportTier(levelNumber);
    final h = height * 1.5;
    final w = h * KLevelArt.supportPillAspect[tier - 1];
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              KLevelArt.supportPill(tier),
              fit: BoxFit.fill,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // The bar runs from ≈ 42 % to ≈ 94 % of the width (measured on
          // the sliced art), its middle at ≈ 55 % of the height.
          Positioned(
            left: w * 0.42,
            right: w * 0.07,
            top: h * 0.3,
            bottom: h * 0.2,
            child: Center(
              child: FittedBox(
                child: Text(
                  '$levelNumber',
                  textDirection: TextDirection.ltr,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: KFonts.latin,
                    fontSize: height * 0.68,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Color(0x99000000), offset: Offset(0, 1)),
                    ],
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

/// Points with thousands separators (`12,500`), Latin digits like every
/// count in the app; BigInt so 64-bit totals are exact on every platform.
String formatPoints(BigInt value) {
  final negative = value.isNegative;
  final digits = value.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return negative ? '-$out' : out.toString();
}

/// A rounded progress bar in the tier's gem colour.
class KLevelProgressBar extends StatelessWidget {
  const new({required this.percent, required this.color, super.key});

  /// 0–100.
  final double percent;
  final Color color;

  static const double height = 6;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: p.surfaceOverlay),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: (percent / 100).clamp(0, 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [color.withValues(alpha: 0.7), color],
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
