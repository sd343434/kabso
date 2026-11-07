// D146: the premium username badge («يوزر مميز»): the tier's medal over a
// plate with the username. D158 (owner: «عدل يوزر مميز ولا تضع قبله @»): a
// premium username has no «@» in front.
//
// D299j (owner, with new art for each tier: «هذه ايقونة الايدي المميز من نوع
// اسطوري، ارسلت لك العناصر وحدها لتقوم انت بتصغير الشريط بحيث يتسع لثلاث
// مقاطع», then the same for «ياقوتي» (four), «ذهبي» (five) and the silver
// (six or more)): every tier is the owner's art (assets/special_id/
// PROVENANCE.md) — the tier's medal over the left end of a glass plate in
// its frame, as the owner combined them. The plate is drawn in slices: its
// curled ends and its centre gem(s) keep their shape; the arcs either side
// of the gem tighten for a short ID (down to [_ArtPlate.minArc] of their
// width) and plain frame and glass widen it for a long one. The shortest
// plate is for the owner's count of characters — LEGEND 3, RUBY 4, GOLD 5,
// SILVER 6 — and never shorter than such an ID needs. The ID is centred in
// the visible glass in gold over a dark outline. The gold staff ID (D299g,
// `KStaffIdText`) is a GOLD badge, so it wears the gold art too.
//
// Motion — D299l (owner-approved, escalating by tier; no entry effect):
//   SILVER  a soft light sweep across the glass every 4 s;
//   GOLD    the sweep every 3 s, and the gems (plate and medal) twinkle one
//           after another;
//   RUBY    the sweep every 2.5 s, the twinkle, and a soft red glow pulsing
//           around the medal;
//   LEGEND  the sweep every 2 s, the twinkle, small stars floating around
//           the plate, and a slow pink → purple → blue glow behind the medal.
// The full set only where the ID is shown prominently ([KSpecialIdEffects
// .full]: the profile bar, the person card, the Me tab); everywhere else
// (chat lines, lists — the default, [KSpecialIdEffects.sweepOnly]) only the
// sweep. All of it runs only while [KSpecialUsername.motion] (off in tests)
// and the widget's `animate` are on and the platform does not ask to reduce
// motion; otherwise the badge is still. One controller per badge drives
// custom painters (no rebuild per frame) and stops with its TickerMode
// (e.g. an off-screen route). The tier always comes from the server
// (`premiumTier`); people without a premium username keep the plain
// username display (this widget is not used for them).

import 'dart:math' as math;

import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// D299l: how much of a tier's motion a badge shows.
enum KSpecialIdEffects {
  /// The tier's whole set (the profile bar, the person card, the Me tab).
  full,

  /// Only the light sweep (chat lines, lists and every other place).
  sweepOnly,
}

/// The medal image of [tier] (the owner's D299j medal; 1x / 2x / 3x).
String kSpecialUsernameMedal(PremiumTier tier) =>
    'assets/special_id/${tier.name}_medal.png';

/// A premium username: the tier's medal and plate with the username (no
/// «@», D158), in left-to-right order whatever the reading direction (it
/// is a Latin handle). Pure display unless [onTap] is given.
class KSpecialUsername extends StatefulWidget {
  const new({
    required this.username,
    required this.tier,
    super.key,
    this.height = 22,
    this.animate = true,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.effects = KSpecialIdEffects.sweepOnly,
  });

  /// Global switch for the light sweep; the test setup turns it off so no
  /// test waits on an endless animation.
  static bool motion = true;

  /// The medal image.
  static const medalKey = Key('kSpecialUsername.medal');

  /// D299j: the plate (its slices inside).
  static const plateKey = Key('kSpecialUsername.plate');

  /// D299l: the glow behind the medal (RUBY, LEGEND; full effects).
  static const glowKey = Key('kSpecialUsername.glow');

  /// D299l: the gems' twinkle and LEGEND's floating stars (full effects).
  static const sparkleKey = Key('kSpecialUsername.sparkle');

  /// D299l: one light sweep's period per tier (the owner's 4 / 3 / 2.5 /
  /// 2 s).
  static Duration sweepPeriod(PremiumTier tier) => switch (tier) {
    PremiumTier.silver => const Duration(milliseconds: 4000),
    PremiumTier.gold => const Duration(milliseconds: 3000),
    PremiumTier.ruby => const Duration(milliseconds: 2500),
    PremiumTier.legend => const Duration(milliseconds: 2000),
  };

  /// D299l: the controller's loop — three sweeps (LEGEND's colour glow
  /// takes the whole loop).
  static Duration loop(PremiumTier tier) => sweepPeriod(tier) * 3;

  final String username;
  final PremiumTier tier;

  /// The badge's scale: the medal is about 1.4 times it (as D146's pill
  /// height, kept so every caller's size reads the same).
  final double height;

  /// Loop the light sweep (still subject to [motion] and reduced motion).
  final bool animate;
  final VoidCallback? onTap;

  /// Read by screen readers instead of the username.
  final String? semanticLabel;

  /// Read after the label (D299h: a staff ID's «official staff ID»).
  final String? semanticHint;

  /// D299l: the tier's full motion or only the sweep.
  final KSpecialIdEffects effects;

  /// Width and height of the badge for [username] at [height].
  static Size measure(String username, PremiumTier tier, double height) =>
      _ArtLayout(_ArtPlate.of(tier), height, username).size;

  /// D299j: the plate's width, the visible glass (where the ID is centred),
  /// the ID's left edge and width, the medal's right edge and where the
  /// plate's own glass begins at its left end (D299k: under the medal), in
  /// the badge's coordinates.
  @visibleForTesting
  static ({
    double plateWidth,
    Rect glass,
    double nameLeft,
    double nameWidth,
    double medalRight,
    double glassEnd,
  })
  geometry(String username, PremiumTier tier, double height) {
    final l = _ArtLayout(_ArtPlate.of(tier), height, username);
    return (
      plateWidth: l.plateW,
      glass: l.glass,
      nameLeft: l.nameX,
      nameWidth: l.nameW,
      medalRight: l.medalLeft + l.mw,
      glassEnd: l.plateLeft + l.hp * l.art.glassLeft,
    );
  }

  /// D299j: the owner's count of characters the tier's shortest plate is
  /// for (LEGEND 3, RUBY 4, GOLD 5, SILVER 6).
  static int shortestFor(PremiumTier tier) => _ArtPlate.of(tier).minChars;

  @override
  State<KSpecialUsername> createState() => _KSpecialUsernameState();
}

class _KSpecialUsernameState extends State<KSpecialUsername>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant KSpecialUsername oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final on =
        KSpecialUsername.motion &&
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context);
    final loop = KSpecialUsername.loop(widget.tier);
    if (on && _c == null) {
      _c = AnimationController(vsync: this, duration: loop)..repeat();
    } else if (on && _c!.duration != loop) {
      _c!
        ..duration = loop
        ..repeat();
    } else if (!on && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final l = _ArtLayout(_ArtPlate.of(tier), widget.height, widget.username);
    Widget slice(String name, double left, double width) => Positioned(
      left: left,
      top: 0,
      width: width,
      height: l.hp,
      child: Image.asset(
        'assets/special_id/${tier.name}_plate_$name.png',
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      ),
    );
    // Left to right: end, fill, arc, gem, arc, fill, end. The fills and
    // arcs reach half a point under their neighbours (no hairline between
    // slices); the ends and the gem are drawn last, over them.
    const seam = .5;
    final xs = <double>[0];
    for (final w in [l.capL, l.fillL, l.arcL, l.gemW, l.arcR, l.fillR]) {
      xs.add(xs.last + w);
    }
    final c = _c;
    final full = c != null && widget.effects == KSpecialIdEffects.full;
    final glow =
        full && (tier == PremiumTier.ruby || tier == PremiumTier.legend);
    final badge = SizedBox.fromSize(
      size: l.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (glow)
            Positioned.fill(
              child: CustomPaint(
                key: KSpecialUsername.glowKey,
                painter: _GlowPainter(l, tier, c),
              ),
            ),
          Positioned(
            key: KSpecialUsername.plateKey,
            left: l.plateLeft,
            top: l.plateTop,
            width: l.plateW,
            height: l.hp,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (l.fillL > 0)
                  slice('fill_left', xs[1] - seam, l.fillL + 2 * seam),
                if (l.fillR > 0)
                  slice('fill_right', xs[5] - seam, l.fillR + 2 * seam),
                slice('wing_left', xs[2] - seam, l.arcL + 2 * seam),
                slice('wing_right', xs[4] - seam, l.arcR + 2 * seam),
                slice('left', xs[0], l.capL),
                slice('gem', xs[3], l.gemW),
                slice('right', xs[6], l.capR),
              ],
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _ArtTextPainter(l, c))),
          Positioned(
            left: l.medalLeft,
            top: 1,
            width: l.mw,
            height: l.md,
            child: Image.asset(
              kSpecialUsernameMedal(tier),
              key: KSpecialUsername.medalKey,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          // SILVER's set is the sweep alone.
          if (full && tier != PremiumTier.silver)
            Positioned.fill(
              child: CustomPaint(
                key: KSpecialUsername.sparkleKey,
                painter: _SparklePainter(l, tier, c),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      label: widget.semanticLabel ?? widget.username,
      hint: widget.semanticHint,
      button: widget.onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(child: badge),
        ),
      ),
    );
  }
}

/// D299j: each tier's owner art — its slices (px of the trimmed plate,
/// assets/special_id/PROVENANCE.md) and how the owner combined medal and
/// plate (`<tier>_full`).
enum _ArtPlate {
  /// LEGEND: purple glass, one gem at the bottom, gold curled ends; the
  /// medal crowned and winged (plate 588 px tall, medal 1190 × 1242 px).
  legend(
    artH: 588,
    capL: 631,
    arcL: 235,
    gemW: 175,
    arcR: 240,
    capR: 638,
    medalScale: 1.06,
    medalAspect: 1190 / 1242,
    medalOfPlate: 1.304,
    medalX: .05,
    plateDy: .095,
    glassTop: .2,
    glassBottom: .76,
    glassLeft: .12,
    glassRight: .12,
    stroke: Color(0xFF2A0A60),
    minChars: 3,
    plateGems: [.833],
    medalGems: [Offset(.5, .126), Offset(.5, .712)],
  ),

  /// RUBY: purple-blue glass, a ruby at the top and bottom centre, pink and
  /// blue ends (plate 639 px tall, medal 594 × 613 px).
  ruby(
    artH: 639,
    capL: 469,
    arcL: 425,
    gemW: 140,
    arcR: 425,
    capR: 463,
    medalScale: 1.04,
    medalAspect: 594 / 613,
    medalOfPlate: 1.193,
    medalX: .32 - 594 / 613 * 1.193 / 2,
    plateDy: .015,
    glassTop: .25,
    glassBottom: .775,
    glassLeft: .13,
    glassRight: .094,
    stroke: Color(0xFF1E0848),
    minChars: 4,
    plateGems: [.11, .79],
    medalGems: [Offset(.51, .135), Offset(.51, .785)],
  ),

  /// GOLD: purple glass, an amethyst at the top and bottom centre, purple
  /// ribbon ends, a gold frame (plate 642 px tall, medal 562 × 605 px).
  gold(
    artH: 642,
    capL: 482,
    arcL: 390,
    gemW: 150,
    arcR: 383,
    capR: 488,
    medalScale: 1,
    medalAspect: 562 / 605,
    medalOfPlate: 1.058,
    medalX: .32 - 562 / 605 * 1.058 / 2,
    plateDy: .035,
    glassTop: .252,
    glassBottom: .754,
    glassLeft: .13,
    glassRight: .09,
    stroke: Color(0xFF2A0A60),
    minChars: 5,
    plateGems: [.123, .754],
    medalGems: [Offset(.51, .11), Offset(.51, .885)],
  ),

  /// SILVER: purple glass, a crystal at the top and bottom centre, lilac
  /// ends, a pearl frame (plate 660 px tall, medal 588 × 596 px).
  silver(
    artH: 660,
    capL: 451,
    arcL: 442,
    gemW: 160,
    arcR: 442,
    capR: 452,
    medalScale: 1.02,
    medalAspect: 588 / 596,
    medalOfPlate: 1.046,
    medalX: .32 - 588 / 596 * 1.046 / 2,
    plateDy: .007,
    glassTop: .245,
    glassBottom: .75,
    glassLeft: .13,
    glassRight: .08,
    stroke: Color(0xFF24104F),
    minChars: 6,
    plateGems: [.114, .727],
    medalGems: [Offset(.51, .12), Offset(.51, .855)],
  );

  new({
    required this.artH,
    required this.capL,
    required this.arcL,
    required this.gemW,
    required this.arcR,
    required this.capR,
    required this.medalScale,
    required this.medalAspect,
    required this.medalOfPlate,
    required this.medalX,
    required this.plateDy,
    required this.glassTop,
    required this.glassBottom,
    required this.glassLeft,
    required this.glassRight,
    required this.stroke,
    required this.minChars,
    required this.plateGems,
    required this.medalGems,
  });

  /// The trimmed plate's height and its slices' widths, px.
  final double artH;
  final double capL;
  final double arcL;
  final double gemW;
  final double arcR;
  final double capR;

  /// The medal's height ÷ (1.35 × [KSpecialUsername.height]), as D146's.
  final double medalScale;

  /// The medal's width ÷ height.
  final double medalAspect;

  /// The medal's height ÷ the plate's.
  final double medalOfPlate;

  /// The medal's centre from the plate's left end, in plate heights. D299k
  /// (owner: no gap between medal and plate): the medal covers the plate's
  /// left end (its curl) and its right edge lies over the glass — 0.32 of
  /// the plate's height from its left end (LEGEND's crowned medal, as the
  /// owner combined it, even further).
  final double medalX;

  /// The plate's centre below the medal's, in plate heights.
  final double plateDy;

  /// The glass inside the frame, in plate heights: its top and bottom from
  /// the plate's top, its round ends from the plate's ends.
  final double glassTop;
  final double glassBottom;
  final double glassLeft;
  final double glassRight;

  /// The ID's outline, dark on the tier's glass.
  final Color stroke;

  /// The owner's count of characters for the shortest plate.
  final int minChars;

  /// D299l: the plate's gem centres, as fractions of the plate's height from
  /// its top (at the gem slice's centre), measured on the owner's art.
  final List<double> plateGems;

  /// D299l: the medal's gem centres, as fractions of the medal's box.
  final List<Offset> medalGems;

  /// The arcs beside the gem tighten down to this share of their width.
  static const double minArc = .25;

  /// The ID's font size, in plate heights.
  static const double font = .47;

  static _ArtPlate of(PremiumTier tier) => switch (tier) {
    PremiumTier.legend => legend,
    PremiumTier.ruby => ruby,
    PremiumTier.gold => gold,
    PremiumTier.silver => silver,
  };
}

/// D299j: a tier's geometry at [h] ([KSpecialUsername.height]).
class _ArtLayout {
  new(this.art, this.h, this.username) : md = h * 1.35 * art.medalScale {
    mw = md * art.medalAspect;
    hp = md / art.medalOfPlate;
    final s = hp / art.artH;
    capL = art.capL * s;
    gemW = art.gemW * s;
    capR = art.capR * s;
    final arcs = (art.arcL + art.arcR) * s;
    nameStyle = TextStyle(
      fontFamily: KFonts.latin,
      fontSize: hp * _ArtPlate.font,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      letterSpacing: .2,
    );
    double widthOf(String text) {
      final p = TextPainter(
        text: TextSpan(text: text, style: nameStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    nameW = widthOf(username);
    // The ID's room: from the medal's edge (or the glass's round left end)
    // to the glass's round right end, with a margin.
    final glassStart = math.max(hp * art.glassLeft, hp * art.medalX + mw / 2);
    final start = glassStart + hp * .16;
    final end = hp * (art.glassRight + .18);
    final fixed = capL + gemW + capR;
    // The shortest plate: the arcs at their tightest, never shorter than
    // the owner's count of characters needs.
    final shortest = math.max(
      fixed + arcs * _ArtPlate.minArc,
      start + widthOf('0' * art.minChars) + end,
    );
    plateW = math.max(shortest, start + nameW + end);
    final k = ((plateW - fixed) / arcs).clamp(0, 1).toDouble();
    arcL = art.arcL * s * k;
    arcR = art.arcR * s * k;
    // Longer still: plain frame and glass, the gem kept near the ID's
    // centre.
    final fill = math.max(0, plateW - fixed - arcs).toDouble();
    final centre = (start + plateW - end) / 2;
    fillL = (centre - capL - arcL - gemW / 2).clamp(0, fill).toDouble();
    fillR = fill - fillL;
    plateLeft = math.max(0, mw / 2 - hp * art.medalX).toDouble() + 1;
    medalLeft = plateLeft + hp * art.medalX - mw / 2;
    plateTop = 1 + md / 2 + hp * art.plateDy - hp / 2;
    glass = Rect.fromLTRB(
      plateLeft + glassStart,
      plateTop + hp * art.glassTop,
      plateLeft + plateW - hp * art.glassRight,
      plateTop + hp * art.glassBottom,
    );
    nameX = plateLeft + centre - nameW / 2;
    gemX = plateLeft + capL + fillL + arcL + gemW / 2;
    size = Size(plateLeft + plateW + 3, md + 2);
  }

  final _ArtPlate art;
  final double h;
  final double md;
  final String username;
  late final double mw;
  late final double hp;
  late final double capL;
  late final double gemW;
  late final double capR;
  late final double arcL;
  late final double arcR;
  late final double fillL;
  late final double fillR;
  late final TextStyle nameStyle;
  late final double nameW;
  late final double plateW;
  late final double medalLeft;
  late final double plateLeft;
  late final double plateTop;
  late final Rect glass;
  late final double nameX;
  late final double gemX;
  late final Size size;
}

/// D299j: the ID (gold over the tier's dark outline, readable on the
/// glass) and D299l's light sweep across the glass.
class _ArtTextPainter extends CustomPainter {
  new(this.l, this.motion) : super(repaint: motion);

  final _ArtLayout l;

  /// The loop (null: still — no sweep).
  final Animation<double>? motion;

  static const _text = [
    Color(0xFFFFFFFF),
    Color(0xFFFFF3C0),
    Color(0xFFFFD34D),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final g = l.glass;
    if (motion case final m?) {
      // Three sweeps per loop; each crosses in the first 45 % of its period.
      final t = (m.value * 3) % 1;
      if (t < .45) {
        final sx = g.left - 20 + (g.width + 40) * (t / .45);
        canvas
          ..save()
          ..clipRRect(RRect.fromRectAndRadius(g, Radius.circular(g.height / 2)))
          ..translate(sx, g.center.dy)
          ..rotate(.35)
          ..drawRect(
            Rect.fromLTWH(-8, -g.height, 16, g.height * 2),
            Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0x00FFFFFF),
                  Color(0x8CFFFFFF),
                  Color(0x00FFFFFF),
                ],
              ).createShader(const Rect.fromLTWH(-8, 0, 16, 1)),
          )
          ..restore();
      }
    }
    final stroke = TextPainter(
      text: TextSpan(
        text: l.username,
        style: l.nameStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.6, l.hp * .07)
            ..strokeJoin = StrokeJoin.round
            ..color = l.art.stroke,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = g.center.dy - stroke.height / 2 + l.hp * .015;
    stroke
      ..paint(canvas, Offset(l.nameX, dy))
      ..dispose();
    TextPainter(
        text: TextSpan(
          text: l.username,
          style: l.nameStyle.copyWith(
            foreground: Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _text,
              ).createShader(Rect.fromLTRB(0, g.top, 1, g.bottom)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(l.nameX, dy))
      ..dispose();
  }

  @override
  bool shouldRepaint(_ArtTextPainter old) =>
      old.motion != motion ||
      old.l.username != l.username ||
      old.l.h != l.h ||
      old.l.art != l.art;
}

/// D299l: RUBY's red glow pulsing around the medal; LEGEND's slow pink →
/// purple → blue glow behind its wings. Drawn under the plate and medal.
class _GlowPainter extends CustomPainter {
  new(this.l, this.tier, this.motion) : super(repaint: motion);

  final _ArtLayout l;
  final PremiumTier tier;
  final Animation<double> motion;

  static const _legend = [
    Color(0xFFFF4DB8),
    Color(0xFFB04DFF),
    Color(0xFF4F8BFF),
    Color(0xFFFF4DB8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = motion.value;
    final centre = Offset(l.medalLeft + l.mw / 2, 1 + l.md / 2);
    final Color colour;
    final double alpha;
    if (tier == PremiumTier.legend) {
      // One colour turn per loop (three sweeps, 6 s).
      final x = v * 3;
      final i = x.floor().clamp(0, 2);
      colour = Color.lerp(_legend[i], _legend[i + 1], x - i)!;
      alpha = .55;
    } else {
      // RUBY: one soft pulse per sweep.
      colour = const Color(0xFFFF2D3A);
      alpha = .25 + .35 * (.5 - .5 * math.cos((v * 3 % 1) * math.pi * 2));
    }
    final radius = l.md * .62;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colour.withValues(alpha: alpha),
            colour.withValues(alpha: alpha * .45),
            colour.withValues(alpha: 0),
          ],
          stops: const [.55, .8, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.motion != motion || old.tier != tier || old.l.h != l.h;
}

/// D299l: the gems twinkle one after another (a small star glint on each
/// gem, the medal's then the plate's, once per sweep); LEGEND adds small
/// stars floating up around the plate.
class _SparklePainter extends CustomPainter {
  new(this.l, this.tier, this.motion) : super(repaint: motion);

  final _ArtLayout l;
  final PremiumTier tier;
  final Animation<double> motion;

  /// Where the gems are, in the badge's coordinates, in twinkle order.
  List<Offset> get gems => [
    for (final g in l.art.medalGems)
      Offset(l.medalLeft + l.mw * g.dx, 1 + l.md * g.dy),
    for (final y in l.art.plateGems) Offset(l.gemX, l.plateTop + l.hp * y),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = motion.value;
    final t = v * 3 % 1;
    final all = gems;
    // Each gem glints for 22 % of a sweep, the next one starting as the
    // last fades (the run fills the sweep's first 80 %).
    for (final (i, gem) in all.indexed) {
      final start = .8 * i / all.length;
      final p = (t - start) / .22;
      if (p <= 0 || p >= 1) continue;
      _star(canvas, gem, l.hp * .2 * math.sin(p * math.pi), p);
    }
    if (tier == PremiumTier.legend) {
      // Five small stars drifting up around the plate, each on its own
      // phase.
      for (var k = 0; k < 5; k++) {
        final p = (v * 2 + k / 5) % 1;
        final x = l.plateLeft + l.plateW * (.18 + .16 * k);
        final y0 = k.isEven ? l.plateTop + l.hp * .9 : l.plateTop + l.hp * .2;
        final pos = Offset(x + 3 * math.sin(p * math.pi * 2), y0 - 6 * p);
        _star(canvas, pos, l.hp * .11 * math.sin(p * math.pi), p);
      }
    }
  }

  void _star(Canvas canvas, Offset at, double r, double spin) {
    if (r <= .2) return;
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(spin * .8)
      ..drawCircle(
        Offset.zero,
        r * .9,
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .5),
      )
      ..drawPath(_sparkle(r), Paint()..color = const Color(0xFFFFFFFF))
      ..restore();
  }

  /// A four-pointed sparkle of radius [r].
  Path _sparkle(double r) => Path()
    ..moveTo(0, -r)
    ..quadraticBezierTo(r * .18, -r * .18, r, 0)
    ..quadraticBezierTo(r * .18, r * .18, 0, r)
    ..quadraticBezierTo(-r * .18, r * .18, -r, 0)
    ..quadraticBezierTo(-r * .18, -r * .18, 0, -r)
    ..close();

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.motion != motion || old.tier != tier || old.l.h != l.h;
}
