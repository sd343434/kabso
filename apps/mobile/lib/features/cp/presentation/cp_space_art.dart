import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/domain/cp_space_models.dart';
import 'package:material_ui/material_ui.dart';

// The CP space's art (CP-021): the owner's pictures in assets/cp_space/
// (PROVENANCE.md has the measurements used below) and the page's pink
// colours, taken from that art. The page always draws on this light pink
// art, whatever the app theme.

/// Colours of the CP space, sampled from assets/cp_space/.
abstract final class CpSpaceColors {
  /// The page under the cards (the background's floor).
  static const page = Color(0xFFFAD3E4);

  /// A section card and its edge.
  static const card = Color(0xF2FFFFFF);
  static const cardTint = Color(0xF2FFF0F6);
  static const cardEdge = Color(0xFFFFFFFF);

  /// Headings and accents (the hero's heart).
  static const accent = Color(0xFFE2276F);
  static const accentDeep = Color(0xFFB8185A);

  /// The progress bar (pink to violet, as the level heart).
  static const progressStart = Color(0xFFFF4FA0);
  static const progressEnd = Color(0xFFA35BE8);
  static const progressTrack = Color(0xFFF3D2E4);

  /// Text on the cards.
  static const ink = Color(0xFF5B2342);
  static const inkSoft = Color(0xFF94627D);

  /// Text on the art (white with a pink shadow).
  static const onArt = Color(0xFFFFFFFF);
  static const artShadow = Color(0xB3A0144F);

  /// A locked privilege.
  static const locked = Color(0xFFB9A3AF);

  /// Chips and buttons on the cards.
  static const chip = Color(0xFFFFE3EF);
}

/// Shadow that keeps white text readable on the art.
const List<Shadow> cpArtTextShadow = [
  Shadow(color: CpSpaceColors.artShadow, blurRadius: 6, offset: Offset(0, 1)),
];

abstract final class CpSpaceAssets {
  static const _dir = 'assets/cp_space';
  static const background = '$_dir/bg.webp';
  static const hero = '$_dir/hero.webp';
  static const ribbon = '$_dir/ribbon.webp';
  static const heart = '$_dir/heart.webp';
  static const frame = '$_dir/cp_avatar_frame.webp';
  static const taskDaily = '$_dir/task_daily.webp';
  static const privilege = '$_dir/privilege.webp';
  static const gift = '$_dir/cp_gift.webp';
  static const ranking = '$_dir/ranking.webp';
  static const coin = 'assets/art/kabso_coin.webp';

  /// The icon of a privilege.
  static String privilegeIcon(CpPrivilegeCode code) => switch (code) {
    CpPrivilegeCode.specialFrame => '$_dir/privilege_frame.webp',
    CpPrivilegeCode.chatBubble => '$_dir/privilege_bubble.webp',
    CpPrivilegeCode.micEffect => '$_dir/privilege_mic.webp',
    CpPrivilegeCode.entranceEffect => '$_dir/privilege_entrance.webp',
    CpPrivilegeCode.giftWall => '$_dir/privilege_gift_wall.webp',
  };

  /// The art of a CP gift card by its `CpConfig.gifts` code; the generic
  /// CP gift for a code this app does not know (or none).
  static String giftArt(String? code) => switch (code) {
    'rose_love' => '$_dir/gift_rose.webp',
    'angel_heart' => '$_dir/gift_angel.webp',
    'love_carriage' => '$_dir/gift_carriage.webp',
    'swan_love' => '$_dir/gift_swan.webp',
    'eternal_heart' => '$_dir/gift_eternal.webp',
    _ => gift,
  };
}

/// The winged heart (`hero.webp`, 1080×679) across [width] with the two
/// partners' pictures in its rings, the days together on its ribbon and
/// the names under the rings. [start] sits in the ring on the reading
/// start side (left in English, right in Arabic).
class CpHero extends StatelessWidget {
  const new({
    required this.width,
    required this.start,
    required this.end,
    required this.days,
    super.key,
    this.onStart,
    this.onEnd,
  });

  final double width;
  final ({String name, String? avatarUrl}) start;
  final ({String name, String? avatarUrl}) end;

  /// The ribbon's text ("7 days").
  final String days;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;

  static const double _w = 1080;
  static const double _h = 679;

  // Ring holes (PROVENANCE.md): centres and diameter in hero pixels.
  static const Offset _left = Offset(259, 363);
  static const Offset _right = Offset(820.5, 364);
  static const double _hole = 190;

  // The ribbon's text area.
  static const Rect _ribbon = Rect.fromLTRB(330, 500, 750, 572);

  static const nameRowHeight = 30.0;

  /// The hero's height (art and names) at [width].
  static double heightFor(double width) => width * _h / _w + nameRowHeight;

  @override
  Widget build(BuildContext context) {
    final s = width / _w;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final (a, b) = rtl ? (end, start) : (start, end);
    final (onA, onB) = rtl ? (onEnd, onStart) : (onStart, onEnd);
    // The picture is a little wider than the hole; the ring covers its edge.
    final d = _hole * s * 1.06;
    final t = context.textStyles;
    Widget avatar(
      Offset c,
      ({String name, String? avatarUrl}) who,
      VoidCallback? onTap,
    ) => Positioned(
      left: c.dx * s - d / 2,
      top: c.dy * s - d / 2,
      width: d,
      height: d,
      child: GestureDetector(
        onTap: onTap,
        child: KAvatar(name: who.name, imageUrl: who.avatarUrl, size: d),
      ),
    );
    Widget name(Offset c, String text) {
      final w = width * 0.4;
      return Positioned(
        left: c.dx * s - w / 2,
        width: w,
        top: _h * s,
        height: nameRowHeight,
        child: Center(
          child: Text(
            KFormat.bidiIsolate(text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: 1.3),
            style: t.bodyStrong.copyWith(
              color: CpSpaceColors.onArt,
              shadows: cpArtTextShadow,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: heightFor(width),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar(_left, a, onA),
          avatar(_right, b, onB),
          // The art over the pictures; taps go through to them.
          Positioned(
            left: 0,
            top: 0,
            width: width,
            height: _h * s,
            child: IgnorePointer(
              child: Image.asset(
                CpSpaceAssets.hero,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Positioned.fromRect(
            rect: Rect.fromLTRB(
              _ribbon.left * s,
              _ribbon.top * s,
              _ribbon.right * s,
              _ribbon.bottom * s,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  days,
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: t.title.copyWith(
                    color: CpSpaceColors.onArt,
                    fontSize: math.max(14, 44 * s),
                    fontWeight: FontWeight.w800,
                    shadows: cpArtTextShadow,
                  ),
                ),
              ),
            ),
          ),
          name(_left, a.name),
          name(_right, b.name),
        ],
      ),
    );
  }
}

/// Hearts (`heart.webp`) rising from the bottom of the area it fills, each
/// with its own size, speed and sway, fading in and out. Never takes taps;
/// nothing at all with reduced motion (`MediaQuery.disableAnimations`).
class CpRisingHearts extends StatefulWidget {
  const new({super.key, this.count = 9});

  final int count;

  /// Widget tests and goldens turn it off (`test/flutter_test_config.dart`).
  static bool animate = true;

  @override
  State<CpRisingHearts> createState() => _CpRisingHeartsState();
}

class _Heart {
  new(math.Random r)
    : x = 0.06 + r.nextDouble() * 0.88,
      size = 14 + r.nextDouble() * 22,
      // Whole laps per cycle, so the loop has no jump.
      laps = 1 + r.nextInt(3),
      phase = r.nextDouble(),
      sway = 6 + r.nextDouble() * 14,
      swayLaps = 1 + r.nextInt(3),
      peak = 0.55 + r.nextDouble() * 0.35;

  final double x;
  final double size;
  final int laps;
  final double phase;
  final double sway;
  final int swayLaps;
  final double peak;
}

class _CpRisingHeartsState extends State<CpRisingHearts>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  late final List<_Heart> _hearts = [
    for (var i = 0; i < widget.count; i++) _Heart(math.Random(i * 7919 + 17)),
  ];
  bool _on = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on =
        CpRisingHearts.animate && !MediaQuery.disableAnimationsOf(context);
    if (on == _on) return;
    _on = on;
    if (on) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_on) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, box) => AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return Stack(
                  children: [
                    for (final h in _hearts) _heart(h, t, box.biggest),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _heart(_Heart h, double t, Size area) {
    final p = (t * h.laps + h.phase) % 1;
    final y = (area.height + h.size) * (1 - p) - h.size;
    final x =
        h.x * area.width +
        math.sin((t * h.swayLaps + h.phase) * 2 * math.pi) * h.sway -
        h.size / 2;
    final opacity = (math.sin(p * math.pi) * h.peak).clamp(0.0, 1.0);
    return Positioned(
      left: x,
      top: y,
      width: h.size,
      height: h.size,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          CpSpaceAssets.heart,
          width: h.size,
          height: h.size,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// A section title on the winged ribbon (`ribbon.webp`, 1200×294).
class CpRibbonTitle extends StatelessWidget {
  const new(this.text, {required this.width, super.key});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 294 / 1200;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              CpSpaceAssets.ribbon,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          // The banner's face: x 22–78 %, y 15–62 %.
          Positioned(
            left: width * 0.22,
            right: width * 0.22,
            top: h * 0.14,
            height: h * 0.5,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: context.textStyles.title.copyWith(
                    color: CpSpaceColors.onArt,
                    fontWeight: FontWeight.w800,
                    shadows: cpArtTextShadow,
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

/// A white card with its ribbon title over the top edge.
class CpSectionCard extends StatelessWidget {
  const new({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final ribbon = math.min<double>(300, box.maxWidth * 0.78);
      final ribbonH = ribbon * 294 / 1200;
      return Padding(
        padding: EdgeInsets.only(top: ribbonH * 0.45),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [CpSpaceColors.cardTint, CpSpaceColors.card],
                ),
                borderRadius: BorderRadius.circular(KRadius.xl),
                border: Border.all(color: CpSpaceColors.cardEdge, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1FB8185A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                KSpacing.md,
                ribbonH * 0.6,
                KSpacing.md,
                KSpacing.md,
              ),
              child: child,
            ),
            Positioned(
              top: -ribbonH * 0.45,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  header: true,
                  child: CpRibbonTitle(title, width: ribbon),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// [child] (a picture) clipped to a heart inside the owner's Special Frame
/// (`cp_avatar_frame.webp`, 768², heart opening x 182–585, y 253–555).
class CpFramedAvatar extends StatelessWidget {
  const new({required this.size, required this.child, super.key});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = size / 768;
    // A little larger than the opening; the frame covers the edge.
    final hole = Rect.fromLTRB(170 * s, 238 * s, 597 * s, 572 * s);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: hole,
            child: ClipPath(clipper: const CpHeartClipper(), child: child),
          ),
          Positioned.fill(
            child: Image.asset(
              CpSpaceAssets.frame,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// A heart filling its box.
class CpHeartClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0.5 * w, 0.98 * h)
      ..cubicTo(0.12 * w, 0.72 * h, -0.04 * w, 0.42 * h, 0.08 * w, 0.18 * h)
      ..cubicTo(0.2 * w, -0.04 * h, 0.44 * w, -0.02 * h, 0.5 * w, 0.2 * h)
      ..cubicTo(0.56 * w, -0.02 * h, 0.8 * w, -0.04 * h, 0.92 * w, 0.18 * h)
      ..cubicTo(1.04 * w, 0.42 * h, 0.88 * w, 0.72 * h, 0.5 * w, 0.98 * h)
      ..close();
  }

  @override
  bool shouldReclip(CpHeartClipper oldClipper) => false;
}
