// D146: the premium username badge («يوزر مميز»), the owner's special-ID
// design (`kabso_special_id`, 2026-10-27; assets/special_id/PROVENANCE.md):
// the tier's medal (owner art, PNG) overlapping a metallic pill drawn in
// code — dark outer rim, the tier gradient, a glossy top layer, an inner
// bevel, «@» and the outlined username, a gold diamond end-cap and a soft
// tier glow. LEGEND's pill is a rainbow that slides and sparkles.
//
// Motion: one soft light sweep across the pill every 2.6 s, only while
// [KSpecialUsername.motion] (off in tests) and the widget's `animate` are
// on and the platform does not ask to reduce motion; the medal stays still.
// The tier always comes from the server (`premiumTier`); people without a
// premium username keep the plain username display (this widget is not
// used for them).

import 'dart:math' as math;

import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The colours of one tier (the owner's palette).
@immutable
class KSpecialUsernameStyle {
  const new({
    required this.pill,
    required this.rim,
    required this.text,
    required this.stroke,
    required this.glow,
    required this.prefix,
  });

  final List<Color> pill;
  final Color rim;
  final List<Color> text;
  final Color stroke;
  final Color glow;
  final Color prefix;

  static const silver = KSpecialUsernameStyle(
    pill: [
      Color(0xFF5E6A80),
      Color(0xFFC9D2E0),
      Color(0xFFF4F7FB),
      Color(0xFF9AA6BA),
      Color(0xFF5A6478),
    ],
    rim: Color(0xFF8E9AB0),
    text: [Color(0xFFFFFFFF), Color(0xFFDDE3EC), Color(0xFF9AA6BA)],
    stroke: Color(0xFF3A4352),
    glow: Color(0xFFC9D2E0),
    prefix: Color(0xFF5A6478),
  );

  static const gold = KSpecialUsernameStyle(
    pill: [
      Color(0xFF7A4706),
      Color(0xFFE0A21A),
      Color(0xFFFFE27A),
      Color(0xFFC98A1E),
      Color(0xFF6E3E04),
    ],
    rim: Color(0xFFB8780A),
    text: [Color(0xFFFFFFFF), Color(0xFFFFF3C0), Color(0xFFFFD34D)],
    stroke: Color(0xFF5A2E00),
    glow: Color(0xFFFFC93C),
    prefix: Color(0xFF6E3E04),
  );

  static const ruby = KSpecialUsernameStyle(
    pill: [
      Color(0xFF4A0004),
      Color(0xFFB8000A),
      Color(0xFFFF3B47),
      Color(0xFFC2000B),
      Color(0xFF5A0006),
    ],
    rim: Color(0xFFB8780A),
    text: [Color(0xFFFFFFFF), Color(0xFFFFE9EA), Color(0xFFFFC1C5)],
    stroke: Color(0xFF4A0004),
    glow: Color(0xFFFF2D3A),
    prefix: Color(0xFFFFC1C5),
  );

  static const legend = KSpecialUsernameStyle(
    pill: [
      Color(0xFFFF4D9A),
      Color(0xFFB04DFF),
      Color(0xFF4FB0FF),
      Color(0xFF3FE0C8),
      Color(0xFFFFC93C),
      Color(0xFFFF4D9A),
    ],
    rim: Color(0xFFB04DFF),
    text: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFE9DBFF)],
    stroke: Color(0xFF2A0A60),
    glow: Color(0xFFB04DFF),
    prefix: Color(0xFFF2E8FF),
  );

  static KSpecialUsernameStyle of(PremiumTier tier) => switch (tier) {
    PremiumTier.legend => legend,
    PremiumTier.ruby => ruby,
    PremiumTier.gold => gold,
    PremiumTier.silver => silver,
  };
}

/// The medal image of [tier] (resolution variants 1x / 2x).
String kSpecialUsernameMedal(PremiumTier tier) =>
    'assets/special_id/medal_${tier.name}.png';

/// A premium username: the tier's medal and pill with `@username`, in
/// left-to-right order whatever the reading direction (it is a Latin
/// handle). Pure display unless [onTap] is given.
class KSpecialUsername extends StatefulWidget {
  const new({
    required this.username,
    required this.tier,
    super.key,
    this.height = 22,
    this.animate = true,
    this.onTap,
    this.semanticLabel,
  });

  /// Global switch for the light sweep; the test setup turns it off so no
  /// test waits on an endless animation.
  static bool motion = true;

  final String username;
  final PremiumTier tier;

  /// The pill's height; the medal is about 1.4 times it.
  final double height;

  /// Loop the light sweep (still subject to [motion] and reduced motion).
  final bool animate;
  final VoidCallback? onTap;

  /// Read by screen readers instead of `@username`.
  final String? semanticLabel;

  /// Width and height of the badge for [username] at [height].
  static Size measure(String username, PremiumTier tier, double height) =>
      _Layout(height, username, _medalScale[tier]!).size;

  @override
  State<KSpecialUsername> createState() => _KSpecialUsernameState();
}

const Map<PremiumTier, double> _medalScale = {
  PremiumTier.silver: 1.02,
  PremiumTier.gold: 1.0,
  PremiumTier.ruby: 1.04,
  PremiumTier.legend: 1.06,
};

/// One loop of the sweep (the owner's 2.6 s).
const _period = Duration(milliseconds: 2600);

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
    if (on && _c == null) {
      _c = AnimationController(vsync: this, duration: _period)..repeat();
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
    final h = widget.height;
    final style = KSpecialUsernameStyle.of(widget.tier);
    final legend = widget.tier == PremiumTier.legend;
    final layout = _Layout(h, widget.username, _medalScale[widget.tier]!);
    final md = layout.md;
    Widget pill(double t) => CustomPaint(
      size: layout.size,
      painter: _PillPainter(layout, style, legend: legend, t: t),
    );
    final c = _c;
    final badge = SizedBox.fromSize(
      size: layout.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (c == null)
            pill(.6)
          else
            AnimatedBuilder(animation: c, builder: (_, _) => pill(c.value)),
          Positioned(
            left: layout.x0 - md / 2,
            top: layout.y0 + h / 2 - md / 2,
            width: md,
            height: md,
            child: Image.asset(
              kSpecialUsernameMedal(widget.tier),
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: widget.semanticLabel ?? '@${widget.username}',
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

/// The badge geometry, measured once per build.
class _Layout {
  new(this.h, this.username, double medalScale)
    : md = h * 1.35 * medalScale,
      prefixStyle = TextStyle(
        fontFamily: KFonts.latin,
        fontSize: h * .55,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        height: 1,
      ),
      nameStyle = TextStyle(
        fontFamily: KFonts.latin,
        fontSize: h * .64,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        height: 1,
        letterSpacing: .2,
      ) {
    final pre = TextPainter(
      text: TextSpan(text: '@', style: prefixStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final name = TextPainter(
      text: TextSpan(text: username, style: nameStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    prefixW = pre.width;
    nameW = name.width;
    pre.dispose();
    name.dispose();
    x0 = md * .5 + 1;
    y0 = (md - h) / 2 + 1;
    left = md * .56;
    w = left + prefixW + 2.5 + nameW + h * .95;
    size = Size(x0 + w + 8, md + 2);
  }

  final double h;
  final double md;
  final String username;
  final TextStyle prefixStyle;
  final TextStyle nameStyle;
  late final double prefixW;
  late final double nameW;
  late final double x0;
  late final double y0;
  late final double left;
  late final double w;
  late final Size size;
}

class _PillPainter extends CustomPainter {
  const new(this.l, this.s, {required this.legend, required this.t});

  final _Layout l;
  final KSpecialUsernameStyle s;
  final bool legend;

  /// The loop's position, 0–1 (the sweep runs in its first 45 %).
  final double t;

  Shader _vertical(double y0, double y1, List<Color> c) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: c,
  ).createShader(Rect.fromLTRB(0, y0, 1, y1));

  @override
  void paint(Canvas canvas, Size size) {
    final h = l.h;
    final x = l.x0;
    final y = l.y0;
    final w = l.w;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(h / 2),
    );
    // Glow, then the dark outer rim, then the tier body.
    canvas
      ..drawRRect(
        body,
        Paint()
          ..color = s.glow.withValues(alpha: .6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawRRect(
        body.inflate(1.2),
        Paint()..shader = _vertical(y, y + h, [s.rim, const Color(0xFF1A0F05)]),
      );
    final bodyPaint = Paint()
      ..shader = legend
          ? LinearGradient(
              colors: s.pill,
              tileMode: TileMode.repeated,
            ).createShader(Rect.fromLTWH(x + w * (t - 1), 0, w, 1))
          : _vertical(y, y + h, s.pill);
    canvas.drawRRect(body, bodyPaint);
    if (legend) {
      canvas.drawRRect(
        body,
        Paint()
          ..shader = _vertical(y, y + h, const [
            Color(0x59FFFFFF),
            Color(0x00FFFFFF),
            Color(0x59000028),
          ]),
      );
    }
    canvas
      ..save()
      ..clipRRect(body)
      // Gloss on the top half.
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 2, y + 1.2, w - 4, h * .46),
          Radius.circular(h * .23),
        ),
        Paint()
          ..shader = _vertical(y, y + h * .5, const [
            Color(0x8CFFFFFF),
            Color(0x0DFFFFFF),
          ]),
      );
    // The light sweep.
    if (t < .45) {
      final sx = x - 20 + (w + 40) * (t / .45);
      canvas
        ..save()
        ..translate(sx, y + h / 2)
        ..rotate(.35)
        ..drawRect(
          Rect.fromLTWH(-8, -h, 16, h * 2),
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0x00FFFFFF), Color(0xBFFFFFFF), Color(0x00FFFFFF)],
            ).createShader(const Rect.fromLTWH(-8, 0, 16, 1)),
        )
        ..restore();
    }
    canvas
      ..restore()
      // Inner bevel.
      ..drawRRect(
        body.deflate(.6),
        Paint()
          ..color = const Color(0x8CFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );

    // «@» then the outlined username.
    final tx = x + l.left;
    final pre = TextPainter(
      text: TextSpan(
        text: '@',
        style: l.prefixStyle.copyWith(color: s.prefix.withValues(alpha: .95)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pre
      ..paint(canvas, Offset(tx, y + h / 2 - pre.height / 2 + .4))
      ..dispose();
    final nx = tx + l.prefixW + 2.5;
    final stroke = TextPainter(
      text: TextSpan(
        text: l.username,
        style: l.nameStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeJoin = StrokeJoin.round
            ..color = s.stroke,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = y + h / 2 - stroke.height / 2 + .8;
    stroke
      ..paint(canvas, Offset(nx, dy))
      ..dispose();
    TextPainter(
        text: TextSpan(
          text: l.username,
          style: l.nameStyle.copyWith(
            foreground: Paint()
              ..shader = _vertical(y + h * .2, y + h * .8, s.text),
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(nx, dy))
      ..dispose();

    // Gold diamond end-cap.
    const cap = Rect.fromLTWH(-2.2, -2.2, 4.4, 4.4);
    canvas
      ..save()
      ..translate(x + w - h * .42, y + h / 2)
      ..rotate(math.pi / 4)
      ..drawRect(
        cap,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF6C8), Color(0xFFE0A21A)],
          ).createShader(cap),
      )
      ..drawRect(
        cap,
        Paint()
          ..color = const Color(0xFF5C3404)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6,
      )
      ..restore();

    // LEGEND sparkles.
    if (legend) {
      for (final (sx, sy, phase) in [
        (x + w - 4, y - 2, 0.0),
        (x + w * .55, y + h + 1, .5),
      ]) {
        final a = math.max(0, math.sin((t + phase) * math.pi * 2)).toDouble();
        if (a == 0) continue;
        canvas
          ..save()
          ..translate(sx, sy)
          ..rotate(t * 3)
          ..drawPath(
            _sparkle(3.2 * a),
            Paint()..color = Colors.white.withValues(alpha: a),
          )
          ..restore();
      }
    }
  }

  Path _sparkle(double r) => Path()
    ..moveTo(0, -r)
    ..quadraticBezierTo(r * .18, -r * .18, r, 0)
    ..quadraticBezierTo(r * .18, r * .18, 0, r)
    ..quadraticBezierTo(-r * .18, r * .18, -r, 0)
    ..quadraticBezierTo(-r * .18, -r * .18, 0, -r)
    ..close();

  @override
  bool shouldRepaint(_PillPainter old) =>
      old.t != t ||
      old.s != s ||
      old.l.username != l.username ||
      old.l.h != l.h;
}
