import 'dart:ui' show ImageFilter;

import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

/// Glyphs of the KL-056 feed and live previews. Every glyph comes from the
/// owner-supplied app icon set ([AppIcons]) except [FeedGlyph.discover], which
/// the set does not have and is drawn here as an outline compass.
enum FeedGlyph {
  heart,
  comment,
  bookmark,
  share,
  search,
  live,
  home,
  homeFilled,
  discover,
  profile,
  close,
  collapse,
  gift,
  coin,
  smiley,
  wave,
  more,
  rank,
}

/// Paints a [FeedGlyph] at [size] in [color]. Rail glyphs get a soft shadow
/// ([shadow]) so they stay readable over any media.
class FeedGlyphIcon extends StatelessWidget {
  const new(
    this.glyph, {
    required this.size,
    required this.color,
    super.key,
    this.shadow = false,
  });

  final FeedGlyph glyph;
  final double size;
  final Color color;
  final bool shadow;

  static const Color _shadowColor = Color(0x59000000);

  /// The [AppIcons] asset of [glyph], or null for the painted compass.
  static String? assetFor(FeedGlyph glyph) => switch (glyph) {
    FeedGlyph.heart => AppIcons.heartFilled,
    FeedGlyph.comment => AppIcons.commentFilled,
    FeedGlyph.bookmark => AppIcons.bookmarkFilled,
    FeedGlyph.share => AppIcons.shareFilled,
    FeedGlyph.search => AppIcons.search,
    FeedGlyph.live => AppIcons.liveTv,
    FeedGlyph.home => AppIcons.home,
    FeedGlyph.homeFilled => AppIcons.homeFilled,
    FeedGlyph.discover => null,
    FeedGlyph.profile => AppIcons.profile,
    FeedGlyph.close => AppIcons.close,
    FeedGlyph.collapse => AppIcons.chevronDownCircle,
    FeedGlyph.gift => AppIcons.giftFilled,
    FeedGlyph.coin => AppIcons.coinGold,
    FeedGlyph.smiley => AppIcons.emoji,
    FeedGlyph.wave => AppIcons.handWave,
    FeedGlyph.more => AppIcons.moreHoriz,
    FeedGlyph.rank => AppIcons.trophy,
  };

  Widget _glyph(Color c, {required bool tint}) {
    final asset = assetFor(glyph);
    if (asset == null) {
      return CustomPaint(size: Size.square(size), painter: _CompassPainter(c));
    }
    return AppIcon(asset, size: size, color: c, tint: tint);
  }

  @override
  Widget build(BuildContext context) {
    // The gold coin keeps its own colours.
    final tint = glyph != FeedGlyph.coin;
    final icon = _glyph(color, tint: tint);
    if (!shadow) return ExcludeSemantics(child: icon);
    final blur = size / 24 * 1.2;
    return ExcludeSemantics(
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, size / 24 * 0.6),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: _glyph(_shadowColor, tint: true),
            ),
          ),
          icon,
        ],
      ),
    );
  }
}

/// Outline compass (Discover) on the 24-unit grid, stroked like the set.
class _CompassPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9))
      ..moveTo(15.4, 8.6)
      ..lineTo(13.3, 13.3)
      ..lineTo(8.6, 15.4)
      ..lineTo(10.7, 10.7)
      ..close();
    canvas
      ..save()
      ..scale(size.width / 24, size.height / 24)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.color != color;
}
