// v1.115-social (D354, CONVENTIONS §10.150): the five leaderboard styles of a
// designed event page (THRONE, PODIUM, CARDS_ROW, SPOTLIGHT, SHIELD_CREST),
// each with its own background layer (or the event's uploaded leaderboard
// background under a scrim), plus the shared kit (gold text, avatars, the
// score format). Promoted from the KL-352 prototype; fed from the real board.
//
// Art: only Kabso's own assets — `assets/leaderboard/*` (D84, generated for
// Kabso), `assets/live_top_frames/*` (owner-supplied, D256),
// `assets/currency/kabso_coin.png`, `assets/flags/*` (Noto, OFL). Everything
// else (pedestals, podium steps, crests, ribbons, beams, particles) is drawn
// here in CustomPainters. The photos are the entrants' own (Kabso's default
// picture without one).
//
// Motion: one ticker per stage (frame shimmer, #1 pulse, particles); with
// reduced motion everything is drawn at rest, and the design may switch the
// shimmer and the pulse off ([StageMotion]).

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/presentation/gift_event_sections.dart'
    show GiftEventMyBar, RankCrown;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// ---- kit -------------------------------------------------------------------

const Color kGold = KBrandColors.gold;
const kGoldLight = Color(0xFFFFE7A3);
const kGoldDeep = Color(0xFFB9832A);
const kWine = Color(0xFF2A0508);
const kWineMid = Color(0xFF5A0A10);
const kWineDeep = Color(0xFF14020A);
const kSilver = Color(0xFFD9DEE8);
const kBronze = Color(0xFFE0A06A);

const kGoldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [kGoldLight, kGold, kGoldDeep],
);

Color rankColor(int rank) => switch (rank) {
  1 => kGold,
  2 => kSilver,
  3 => kBronze,
  _ => kGoldDeep,
};

List<Color> rankMetal(int rank) => switch (rank) {
  1 => const [Color(0xFFFFF0B8), kGold, Color(0xFF9C6A1C)],
  2 => const [Color(0xFFFFFFFF), Color(0xFFC3CAD6), Color(0xFF6E7684)],
  _ => const [Color(0xFFFFD2A8), Color(0xFFCD8A52), Color(0xFF7A4522)],
};

/// Score with K / M / B, two decimals floored, trailing zeros dropped,
/// isolated left-to-right (60.98M, 36.44M, 986.4K).
String eventScore(int v) {
  if (v < 1000) return '\u2066$v\u2069';
  final (div, suf) = switch (v) {
    >= 1000000000 => (1000000000, 'B'),
    >= 1000000 => (1000000, 'M'),
    _ => (1000, 'K'),
  };
  final hund = v * 100 ~/ div;
  var text = '${hund ~/ 100}.${(hund % 100).toString().padLeft(2, '0')}';
  text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return '\u2066$text$suf\u2069';
}

@immutable
class LbEntry {
  const new({
    required this.rank,
    required this.name,
    required this.score,
    this.flag,
    this.photo,
    this.isMe = false,
  });

  final int rank;
  final String name;

  /// ISO code of `assets/flags/<code>.webp`; null: no flag.
  final String? flag;
  final int score;

  /// The entrant's photo, or null for Kabso's default avatar.
  final ImageProvider? photo;

  /// The caller's own row.
  final bool isMe;
}

/// The design's motion switches for a stage below it (D354): the light
/// sweep and the first place's pulse. Reduced motion stops both anyway.
class StageMotion extends InheritedWidget {
  const new({
    required this.shimmer,
    required this.pulseFirst,
    required super.child,
    super.key,
  });

  final bool shimmer;
  final bool pulseFirst;

  static bool shimmerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StageMotion>()?.shimmer ??
      true;

  static bool pulseOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StageMotion>()?.pulseFirst ??
      true;

  @override
  bool updateShouldNotify(StageMotion old) =>
      old.shimmer != shimmer || old.pulseFirst != pulseFirst;
}

/// Gold gradient text with a dark outline, for titles and numerals.
class GoldText extends StatelessWidget {
  const new(
    this.text, {
    required this.style,
    this.gradient = kGoldGradient,
    this.stroke = 0,
    super.key,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;
  final double stroke;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (stroke > 0)
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF3A0508),
            shadows: const [
              Shadow(
                color: Color(0xCC000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: gradient.createShader,
        child: Text(text, style: style.copyWith(color: Colors.white)),
      ),
    ],
  );
}

class Avatar extends StatelessWidget {
  const new(
    this.photo, {
    required this.size,
    this.ring,
    this.ringWidth = 2,
    super.key,
  });

  final ImageProvider? photo;
  final double size;
  final List<Color>? ring;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(
      KDefaultAvatarArt.small,
      width: size,
      height: size,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    );
    final img = ClipOval(
      child: photo == null
          ? fallback()
          : Image(
              image: photo!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
    if (ring == null) return img;
    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ring!,
        ),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 6)],
      ),
      child: img,
    );
  }
}

class Flag extends StatelessWidget {
  const new(this.code, {this.height = 12, super.key});

  final String code;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: Image.asset(
      'assets/flags/$code.webp',
      height: height,
      width: height * 4 / 3,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    ),
  );
}

class CoinIcon extends StatelessWidget {
  const new({this.size = 14, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/currency/kabso_coin.png',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

/// Name + flag on one line, ellipsised.
class NameFlag extends StatelessWidget {
  const new(this.e, {required this.style, this.center = true, super.key});

  final LbEntry e;
  final TextStyle style;
  final bool center;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
    mainAxisAlignment: center
        ? MainAxisAlignment.center
        : MainAxisAlignment.start,
    children: [
      Flexible(
        child: Text(
          e.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
      if (e.flag case final flag?) ...[
        const SizedBox(width: 4),
        Flag(flag, height: (style.fontSize ?? 13) * .8),
      ],
    ],
  );
}

/// Coin + score in a wine pill with a gold rim.
class ScorePlate extends StatelessWidget {
  const new(this.score, {this.big = false, this.metal, super.key});

  final int score;
  final bool big;
  final List<Color>? metal;

  // A narrow seat or a large text size scales the plate down (D354).
  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: _plate());

  Widget _plate() => Container(
    padding: EdgeInsets.symmetric(
      horizontal: big ? 12 : 8,
      vertical: big ? 4 : 2,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xE65A0A10), Color(0xF22A0508)],
      ),
      borderRadius: BorderRadius.circular(KRadius.pill),
      border: Border.all(color: (metal ?? rankMetal(1))[1]),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: big ? 16 : 13),
        const SizedBox(width: 4),
        Text(
          eventScore(score),
          style: TextStyle(
            fontFamily: KFonts.latin,
            fontSize: big ? 15 : 12,
            fontWeight: FontWeight.w800,
            color: kGoldLight,
            height: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// A shared ticker for a stage (one continuous animation per stage).
class StageClock extends StatefulWidget {
  const new({required this.builder, this.reduceMotion, super.key});

  final Widget Function(BuildContext context, ({double t, bool motion}) at)
  builder;
  final bool? reduceMotion;

  @override
  State<StageClock> createState() => _StageClockState();
}

class _StageClockState extends State<StageClock>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (e) => _t.value = e.inMicroseconds / 1e6,
  );
  final _t = ValueNotifier<double>(0);
  bool _motion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = !(widget.reduceMotion ?? MediaQuery.disableAnimationsOf(context));
    if (_motion && !_ticker.isActive) _ticker.start();
    if (!_motion && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: _t,
    builder: (context, t, _) =>
        widget.builder(context, (t: t, motion: _motion)),
  );
}

/// A diagonal light sweep over [child] (frames, plates), period 2.8 s.
class Shimmer extends StatelessWidget {
  const new({
    required this.t,
    required this.motion,
    required this.child,
    this.period = 2.8,
    super.key,
  });

  final double t;
  final bool motion;
  final double period;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!motion || !StageMotion.shimmerOf(context)) return child;
    final p = (t % period) / period; // sweep in the first 45 %
    if (p > .45) return child;
    final x = -1.6 + p / .45 * 3.2;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment(x - .5, -1),
        end: Alignment(x + .5, 1),
        colors: const [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
        stops: const [.35, .5, .65],
      ).createShader(r),
      child: child,
    );
  }
}

/// A four-point sparkle.
void paintSparkle(Canvas canvas, Offset c, double r, Color color) {
  final p = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
    ..close();
  canvas
    ..drawCircle(
      c,
      r * .8,
      Paint()
        ..color = color.withValues(alpha: color.a * .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    )
    ..drawPath(p, Paint()..color = color);
}

/// A five-point star.
Path starPath(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final rr = i.isEven ? r : r * .45;
    final o = c + Offset(math.cos(a), math.sin(a)) * rr;
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

// ---- styles ----------------------------------------------------------------

enum LeaderboardStyle {
  /// 1. Big #1 on a pedestal under stars, #2 / #3 lower left and right.
  throne,

  /// 2. A 3-step podium (2-1-3) in gold, silver and bronze with light beams.
  podium,

  /// 3. Three tall trophy cards, #1 taller in the middle, glowing rims.
  cardsRow,

  /// 4. #1 as a full-width spotlight banner, #2 / #3 as half cards.
  spotlight,

  /// 5. Crest shields with ribbons per rank.
  shieldCrest,
}

/// The leaderboard area: its own background, the top three in [style],
/// rows 4+ and (outside, by the page) the «مركزي» bar.
class LeaderboardStage extends StatelessWidget {
  const new({
    required this.style,
    required this.entries,
    this.background,
    this.reduceMotion,
    this.rowsLimit = 4,
    this.withBackground = true,
    super.key,
  });

  final LeaderboardStyle style;
  final List<LbEntry> entries;

  /// An admin-uploaded leaderboard background (drawn under a scrim).
  final ImageProvider? background;
  final bool? reduceMotion;
  final int rowsLimit;
  final bool withBackground;

  LbEntry? _at(int rank) {
    for (final e in entries) {
      if (e.rank == rank) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => StageClock(
    reduceMotion: reduceMotion,
    builder: (context, at) {
      final (:t, :motion) = at;
      final top = [_at(1), _at(2), _at(3)];
      final rows = entries.where((e) => e.rank > 3).take(rowsLimit).toList();
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (style) {
            LeaderboardStyle.throne => _Throne(top, t, motion: motion),
            LeaderboardStyle.podium => _Podium(top, t, motion: motion),
            LeaderboardStyle.cardsRow => _CardsRow(top, t, motion: motion),
            LeaderboardStyle.spotlight => _Spotlight(top, t, motion: motion),
            LeaderboardStyle.shieldCrest => _Shields(top, t, motion: motion),
          },
          const SizedBox(height: KSpacing.md),
          if (rows.isEmpty)
            for (final r in [4, 5])
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.lg,
                  0,
                  KSpacing.lg,
                  KSpacing.sm,
                ),
                child: Opacity(opacity: .55, child: OpenRow(rank: r)),
              ),
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                0,
                KSpacing.lg,
                KSpacing.sm,
              ),
              child: RankRow(e, style: style),
            ),
        ],
      );
      if (!withBackground) return content;
      return Stack(
        children: [
          Positioned.fill(
            child: StageBackground(
              style: style,
              t: t,
              motion: motion,
              image: background,
            ),
          ),
          content,
        ],
      );
    },
  );
}

/// Each style's own background layer (or the admin's image under a scrim).
class StageBackground extends StatelessWidget {
  const new({
    required this.style,
    required this.t,
    required this.motion,
    this.image,
    super.key,
  });

  final LeaderboardStyle style;
  final double t;
  final bool motion;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final base = image != null
        ? Image(
            image: image!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          )
        : style == LeaderboardStyle.throne
        ? Image.asset(
            'assets/leaderboard/background.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          )
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        ?base,
        RepaintBoundary(
          child: CustomPaint(
            painter: _BgPainter(
              style,
              t,
              motion: motion,
              overImage: base != null,
            ),
          ),
        ),
      ],
    );
  }
}

class _BgPainter extends CustomPainter {
  new(this.style, this.t, {required this.motion, required this.overImage});

  final LeaderboardStyle style;
  final double t;
  final bool motion;
  final bool overImage;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final w = size.width;
    if (!overImage) {
      final colors = switch (style) {
        LeaderboardStyle.podium => const [Color(0xFF4A0710), Color(0xFF1A0206)],
        LeaderboardStyle.cardsRow => const [
          Color(0xFF3A0610),
          Color(0xFF12020A),
        ],
        LeaderboardStyle.spotlight => const [
          Color(0xFF26040A),
          Color(0xFF07010A),
        ],
        _ => const [Color(0xFF6A0A16), Color(0xFF1E0308)],
      };
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -.75),
            radius: 1.25,
            colors: colors,
          ).createShader(r),
      );
    }
    switch (style) {
      case LeaderboardStyle.podium:
        _beams(canvas, size, Offset(w / 2, -20), 5, kGold, .10);
      case LeaderboardStyle.cardsRow:
        // Silk: soft diagonal folds.
        for (var i = -4; i < 10; i++) {
          final x = i * 70.0 + (motion ? math.sin(t * .4 + i) * 6 : 0);
          final p = Path()
            ..moveTo(x, 0)
            ..cubicTo(
              x + 60,
              size.height * .3,
              x - 40,
              size.height * .6,
              x + 50,
              size.height,
            )
            ..lineTo(x + 80, size.height)
            ..cubicTo(
              x - 10,
              size.height * .6,
              x + 90,
              size.height * .3,
              x + 30,
              0,
            )
            ..close();
          canvas.drawPath(
            p,
            Paint()
              ..color = (i.isEven ? Colors.white : Colors.black).withValues(
                alpha: i.isEven ? .025 : .12,
              )
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
        }
      case LeaderboardStyle.spotlight:
        final sway = motion ? math.sin(t * .6) * .12 : 0;
        _beams(
          canvas,
          size,
          Offset(w * .15, -30),
          1,
          const Color(0xFFFFE3B0),
          .16,
          spread: .32,
          tilt: .55 + sway,
        );
        _beams(
          canvas,
          size,
          Offset(w * .85, -30),
          1,
          const Color(0xFFFFB0B8),
          .10,
          spread: .30,
          tilt: -.55 - sway,
        );
      case LeaderboardStyle.shieldCrest:
        // Diamond lattice.
        final lp = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = kGold.withValues(alpha: .07);
        for (var x = -size.height; x < w + size.height; x += 34) {
          canvas
            ..drawLine(Offset(x, 0), Offset(x + size.height, size.height), lp)
            ..drawLine(Offset(x, 0), Offset(x - size.height, size.height), lp);
        }
      case LeaderboardStyle.throne:
        canvas.drawRect(
          r,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x33000000), Color(0xB3100205)],
              stops: [0, .5, 1],
            ).createShader(r),
        );
    }
    if (overImage && style != LeaderboardStyle.throne) {
      canvas.drawRect(r, Paint()..color = const Color(0x66000000));
    }
    // Rising gold dust (all styles).
    {
      final rnd = math.Random(style.index + 3);
      for (var i = 0; i < 26; i++) {
        final x0 = rnd.nextDouble() * w;
        final speed = 10 + rnd.nextDouble() * 18;
        final y =
            (rnd.nextDouble() * size.height - (motion ? t * speed : 0)) %
            size.height;
        final a =
            .25 +
            .5 * (motion ? (math.sin(t * 2 + i) * .5 + .5) : rnd.nextDouble());
        canvas.drawCircle(
          Offset(x0 + (motion ? math.sin(t + i) * 4 : 0), y),
          .8 + rnd.nextDouble() * 1.6,
          Paint()..color = kGoldLight.withValues(alpha: a * .6),
        );
      }
    }
  }

  void _beams(
    Canvas canvas,
    Size size,
    Offset o,
    int n,
    Color c,
    double a, {
    double spread = .9,
    double tilt = 0,
  }) {
    for (var i = 0; i < n; i++) {
      final ang =
          math.pi / 2 + tilt + (n == 1 ? 0 : (i / (n - 1) - .5) * spread * 1.6);
      final len = size.height * 1.2;
      final half = .07 + (n == 1 ? spread * .3 : 0);
      final p = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(
          o.dx + math.cos(ang - half) * len,
          o.dy + math.sin(ang - half) * len,
        )
        ..lineTo(
          o.dx + math.cos(ang + half) * len,
          o.dy + math.sin(ang + half) * len,
        )
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(o.dx / size.width * 2 - 1, -1),
            radius: 1.3,
            colors: [
              c.withValues(alpha: a * 2),
              c.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t || old.motion != motion;
}

// ---- 1. Throne -------------------------------------------------------------

/// A podium frame (D84 art) with the photo filling its measured opening.
class PodiumFrame extends StatelessWidget {
  const new(
    this.rank,
    this.photo, {
    required this.width,
    this.empty = false,
    super.key,
  });

  final int rank;
  final ImageProvider? photo;
  final double width;
  final bool empty;

  static const _hole = <int, (double, double, double)>{
    1: (0.557, 0.243, 461 / 480),
    2: (0.554, 0.230, 415 / 480),
    3: (0.571, 0.226, 375 / 480),
  };

  @override
  Widget build(BuildContext context) {
    final (cy, r, aspect) = _hole[rank]!;
    final height = width * aspect;
    final d = (r * width + 2) * 2;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: width / 2 - d / 2,
            top: cy * height - d / 2,
            child: empty
                ? Container(
                    width: d,
                    height: d,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF3A0810),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: d * .55,
                      color: kGold.withValues(alpha: .45),
                    ),
                  )
                : Avatar(photo, size: d),
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

class _Throne extends StatelessWidget {
  const new(this.top, this.t, {required this.motion});

  final List<LbEntry?> top;
  final double t;
  final bool motion;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, c) => _build(context, c.maxWidth));

  Widget _build(BuildContext context, double width) {
    // #2 / #3 shrink on narrow phones so #1's name keeps ≥ 120 dp.
    final sideW = ((width - 120) / 2).clamp(96.0, 132.0);
    final ts = context.textStyles;
    final pulse = motion && StageMotion.pulseOf(context)
        ? (math.sin(t * math.pi * 2 / 2.4) * .5 + .5)
        : .5;
    Widget side(int rank, LbEntry? e) => SizedBox(
      width: sideW,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Shimmer(
            t: t + rank,
            motion: motion,
            child: PodiumFrame(
              rank,
              e?.photo,
              width: sideW - 8,
              empty: e == null,
            ),
          ),
          const SizedBox(height: 2),
          _Pedestal(rank: rank, width: sideW - 22),
          const SizedBox(height: 6),
          if (e == null)
            Text(
              context.l10n.eventsSeatOpen,
              style: ts.label.copyWith(color: kGoldLight.withValues(alpha: .8)),
            )
          else ...[
            NameFlag(
              e,
              style: ts.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            ScorePlate(e.score, metal: rankMetal(rank)),
          ],
        ],
      ),
    );
    final one = top[0];
    return SizedBox(
      height: 452,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // #1's halo, pulsing slowly.
          Positioned(
            top: 30,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kGold.withValues(alpha: .28 + .22 * pulse),
                    kGold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: SizedBox(
              width: 120,
              height: 26,
              child: CustomPaint(painter: _StarsPainter(t, motion: motion)),
            ),
          ),
          Positioned(
            top: 26,
            child: Column(
              children: [
                Shimmer(
                  t: t,
                  motion: motion,
                  child: PodiumFrame(
                    1,
                    one?.photo,
                    width: 196,
                    empty: one == null,
                  ),
                ),
                const _Pedestal(rank: 1, width: 170),
                const SizedBox(height: 6),
                if (one != null) ...[
                  NameFlag(
                    one,
                    style: ts.title.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ScorePlate(one.score, big: true),
                ],
              ],
            ),
          ),
          // 2-1-3 from left to right in both languages (D84).
          Positioned(left: 0, top: 232, child: side(2, top[1])),
          Positioned(right: 0, top: 232, child: side(3, top[2])),
        ],
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  new(this.t, {required this.motion});

  final double t;
  final bool motion;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 5; i++) {
      final d = (i - 2).abs();
      final r = 9.0 - d * 2;
      final c = Offset(
        size.width / 2 + (i - 2) * 24,
        size.height - 10 - (2 - d) * 4,
      );
      final tw = motion ? .75 + .25 * math.sin(t * 3 + i) : 1;
      final p = starPath(c, r);
      canvas
        ..drawPath(
          p,
          Paint()
            ..color = kGold.withValues(alpha: .5 * tw)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..drawPath(
          p,
          Paint()
            ..shader = kGoldGradient.createShader(
              Rect.fromCircle(center: c, radius: r),
            ),
        );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.t != t;
}

/// An oval stage: gold rim, velvet top, a metal front with the numeral.
class _Pedestal extends StatelessWidget {
  const new({required this.rank, required this.width});

  final int rank;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * .2,
    child: CustomPaint(painter: _PedestalPainter(rank)),
  );
}

class _PedestalPainter extends CustomPainter {
  new(this.rank);

  final int rank;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final metal = rankMetal(rank);
    final topH = h * .55;
    final front = Path()
      ..moveTo(0, topH / 2)
      ..lineTo(0, h - topH / 2)
      ..arcToPoint(
        Offset(w, h - topH / 2),
        radius: Radius.elliptical(w / 2, topH / 2),
        clockwise: false,
      )
      ..lineTo(w, topH / 2)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = LinearGradient(
          colors: [metal[2], metal[1], metal[0], metal[1], metal[2]],
        ).createShader(Offset.zero & size),
    );
    final top = Rect.fromLTWH(0, 0, w, topH);
    canvas
      ..drawOval(
        top,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF8A0E1A), Color(0xFF3A050B)],
          ).createShader(top),
      )
      ..drawOval(
        top.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = metal[0],
      );
  }

  @override
  bool shouldRepaint(_PedestalPainter old) => false;
}

// ---- 2. Podium -------------------------------------------------------------

class _Podium extends StatelessWidget {
  const new(this.top, this.t, {required this.motion});

  final List<LbEntry?> top;
  final double t;
  final bool motion;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    Widget column(int rank, double avatar, double step) {
      final e = top[rank - 1];
      final metal = rankMetal(rank);
      return SizedBox(
        width: 116,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            RankCrown(rank: rank, size: rank == 1 ? 34 : 26),
            const SizedBox(height: 2),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Avatar(e?.photo, size: avatar, ring: metal, ringWidth: 3),
                Positioned(bottom: -10, child: _Medal(rank: rank, size: 24)),
              ],
            ),
            const SizedBox(height: 14),
            if (e != null) ...[
              NameFlag(
                e,
                style: ts.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              ScorePlate(e.score, metal: metal),
            ] else
              Text(
                context.l10n.eventsSeatOpen,
                style: ts.label.copyWith(color: kGoldLight),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: 116,
              height: step,
              child: CustomPaint(
                painter: _StepPainter(rank, motion ? t : 0),
                child: Center(
                  child: GoldText(
                    '$rank',
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, metal[0]],
                    ),
                    style: const TextStyle(
                      fontFamily: KFonts.latin,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                    stroke: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 372,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [column(2, 72, 96), column(1, 92, 132), column(3, 68, 74)],
        ),
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const new({required this.rank, required this.size});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: rankMetal(rank),
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .8)),
      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 4)],
    ),
    child: Text(
      '$rank',
      style: TextStyle(
        fontFamily: KFonts.latin,
        fontSize: size * .55,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF3A0508),
        height: 1,
      ),
    ),
  );
}

class _StepPainter extends CustomPainter {
  new(this.rank, this.t);

  final int rank;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final metal = rankMetal(rank);
    const lip = 12.0;
    final topFace = Path()
      ..moveTo(6, lip)
      ..lineTo(14, 0)
      ..lineTo(w - 14, 0)
      ..lineTo(w - 6, lip)
      ..close();
    canvas.drawPath(
      topFace,
      Paint()..color = Color.lerp(metal[0], Colors.white, .3)!,
    );
    final front = Rect.fromLTWH(6, lip, w - 12, h - lip);
    canvas
      ..drawRect(
        front,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              metal[1],
              Color.lerp(metal[2], const Color(0xFF2A0508), .5)!,
            ],
          ).createShader(front),
      )
      // Side bevels.
      ..drawRect(
        Rect.fromLTWH(6, lip, 6, h - lip),
        Paint()..color = Colors.white.withValues(alpha: .18),
      )
      ..drawRect(
        Rect.fromLTWH(w - 12, lip, 6, h - lip),
        Paint()..color = Colors.black.withValues(alpha: .25),
      );
    // A glint that runs across the top edge.
    if (t > 0) {
      final x = (t * 60 + rank * 40) % (w * 3) - w;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 18, lip + 2),
        Paint()
          ..color = Colors.white.withValues(alpha: .45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(_StepPainter old) => old.t != t;
}

// ---- 3. Cards row ----------------------------------------------------------

class _CardsRow extends StatelessWidget {
  const new(this.top, this.t, {required this.motion});

  final List<LbEntry?> top;
  final double t;
  final bool motion;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    final pulse = motion && StageMotion.pulseOf(context)
        ? (math.sin(t * math.pi * 2 / 2.4) * .5 + .5)
        : .5;
    Widget card(int rank, double w, double h, double avatar) {
      final e = top[rank - 1];
      final metal = rankMetal(rank);
      return Container(
        width: w,
        height: h,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.lg + 2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: metal,
          ),
          boxShadow: [
            BoxShadow(
              color: metal[1].withValues(
                alpha: rank == 1 ? .35 + .35 * pulse : .3,
              ),
              blurRadius: rank == 1 ? 14 + 10 * pulse : 10,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.lg),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6A0E18), Color(0xFF2A0508), Color(0xFF1A0306)],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _Medal(rank: rank, size: rank == 1 ? 30 : 26),
              const Spacer(),
              Shimmer(
                t: t + rank * .7,
                motion: motion,
                child: Avatar(
                  e?.photo,
                  size: avatar,
                  ring: metal,
                  ringWidth: 3,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: e == null
                    ? Text(
                        context.l10n.eventsSeatOpen,
                        style: ts.label.copyWith(color: kGoldLight),
                      )
                    : NameFlag(
                        e,
                        style: ts.label.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              if (e != null) ScorePlate(e.score, metal: metal),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.sm),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            card(2, 110, 206, 66),
            const SizedBox(width: 9),
            card(1, 126, 246, 82),
            const SizedBox(width: 9),
            card(3, 110, 196, 62),
          ],
        ),
      ),
    );
  }
}

// ---- 4. Spotlight ----------------------------------------------------------

/// A live-top frame (owner art, D256) around a photo.
class TopFrame extends StatelessWidget {
  const new(this.rank, this.photo, {required this.size, super.key});

  final int rank;
  final ImageProvider? photo;
  final double size;

  static const _win = <int, (double, double, double)>{
    1: (0.494, 0.523, 0.592),
    2: (0.497, 0.493, 0.594),
    3: (0.499, 0.487, 0.582),
  };

  @override
  Widget build(BuildContext context) {
    final (cx, cy, dd) = _win[rank]!;
    final d = dd * size + 4;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned(
            left: cx * size - d / 2,
            top: cy * size - d / 2,
            child: Avatar(photo, size: d),
          ),
          Positioned.fill(
            child: Image.asset(
              'assets/live_top_frames/top_$rank.webp',
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Spotlight extends StatelessWidget {
  const new(this.top, this.t, {required this.motion});

  final List<LbEntry?> top;
  final double t;
  final bool motion;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    final l10n = context.l10n;
    final one = top[0];
    Widget half(int rank) {
      final e = top[rank - 1];
      final metal = rankMetal(rank);
      return Expanded(
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.lg),
            gradient: LinearGradient(colors: [metal[0], metal[2]]),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.lg - 1.5),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF24A0810), Color(0xF21A0306)],
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 8, 8),
            child: Row(
              children: [
                TopFrame(rank, e?.photo, size: 76),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.eventsRank('$rank'),
                        style: ts.caption.copyWith(
                          color: metal[0],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (e != null) ...[
                        NameFlag(
                          e,
                          center: false,
                          style: ts.label.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ScorePlate(e.score, metal: metal),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Column(
        children: [
          Container(
            height: 178,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.xl),
              gradient: kGoldGradient,
              boxShadow: [
                BoxShadow(color: kGold.withValues(alpha: .35), blurRadius: 18),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KRadius.xl - 2),
              child: CustomPaint(
                painter: _SpotPainter(t, motion: motion),
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    Shimmer(
                      t: t,
                      motion: motion,
                      child: TopFrame(1, one?.photo, size: 150),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const RankCrown(rank: 1),
                              const SizedBox(width: 6),
                              Text(
                                l10n.eventsRank('1'),
                                style: ts.label.copyWith(
                                  color: kGoldLight,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (one != null) ...[
                            NameFlag(
                              one,
                              center: false,
                              style: ts.headline.copyWith(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ScorePlate(one.score, big: true),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: KSpacing.md),
          Row(
            children: [
              half(2),
              const SizedBox(width: KSpacing.sm),
              half(3),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  new(this.t, {required this.motion});

  final double t;
  final bool motion;

  static const List<Color> _confetti = [
    kGold,
    KBrandColors.red400,
    Colors.white,
    Color(0xFFFFB347),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A0A14), Color(0xFF22040A)],
        ).createShader(r),
    );
    // The spotlight cone onto #1.
    final sway = motion ? math.sin(t * .8) * 8 : 0.0;
    final p = Path()
      ..moveTo(size.width * .18 - 16, -10)
      ..lineTo(size.width * .18 + 16, -10)
      ..lineTo(size.width * .30 + 70 + sway, size.height)
      ..lineTo(size.width * .30 - 110 + sway, size.height)
      ..close();
    canvas
      ..drawPath(
        p,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x80FFF1C9), Color(0x00FFF1C9)],
          ).createShader(r)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .3 + sway - 20, size.height - 6),
          width: 170,
          height: 26,
        ),
        Paint()
          ..color = const Color(0x55FFE3A0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    // Confetti falling.
    final rnd = math.Random(11);
    for (var i = 0; i < 26; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 18 + rnd.nextDouble() * 22;
      final y =
          (rnd.nextDouble() * size.height + (motion ? t * speed : 0)) %
              (size.height + 10) -
          5;
      final ang = (motion ? t * (1 + rnd.nextDouble() * 2) : 0.0) + i;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(ang)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5,
            height: 2.5 + 2 * math.cos(ang * 2).abs(),
          ),
          Paint()..color = _confetti[i % 4].withValues(alpha: .8),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_SpotPainter old) => old.t != t;
}

// ---- 5. Shield crest -------------------------------------------------------

class _Shields extends StatelessWidget {
  const new(this.top, this.t, {required this.motion});

  final List<LbEntry?> top;
  final double t;
  final bool motion;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    final pulse = motion && StageMotion.pulseOf(context)
        ? (math.sin(t * math.pi * 2 / 2.4) * .5 + .5)
        : .5;
    Widget crest(int rank, double w) {
      final e = top[rank - 1];
      final metal = rankMetal(rank);
      final h = w * 155 / 128;
      return SizedBox(
        width: w + 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: w + 30,
              height: h + 16,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (rank == 1)
                    Positioned(
                      top: -20,
                      child: Container(
                        width: w + 60,
                        height: w + 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              kGold.withValues(alpha: .25 + .25 * pulse),
                              kGold.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Shimmer(
                    t: t + rank,
                    motion: motion,
                    child: CustomPaint(
                      size: Size(w, h),
                      painter: _ShieldPainter(rank),
                    ),
                  ),
                  Positioned(
                    top: h * .17,
                    child: Avatar(
                      e?.photo,
                      size: w * .56,
                      ring: metal,
                      ringWidth: 2.5,
                    ),
                  ),
                  Positioned(
                    top: h * .70,
                    child: GoldText(
                      '$rank',
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, metal[1]],
                      ),
                      style: TextStyle(
                        fontFamily: KFonts.latin,
                        fontSize: w * .2,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                      stroke: 3,
                    ),
                  ),
                  // Ribbon across the shield's foot.
                  Positioned(
                    bottom: 0,
                    child: SizedBox(
                      width: w + 30,
                      height: 30,
                      child: CustomPaint(
                        painter: _BannerPainter(metal),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: e == null
                                ? Text(
                                    context.l10n.eventsSeatOpen,
                                    style: ts.caption.copyWith(
                                      color: Colors.white,
                                    ),
                                  )
                                : NameFlag(
                                    e,
                                    style: ts.label.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (e != null) ScorePlate(e.score, metal: metal, big: rank == 1),
          ],
        ),
      );
    }

    return SizedBox(
      height: 352,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(top: 4, child: crest(1, 132)),
          Positioned(left: 4, top: 128, child: crest(2, 100)),
          Positioned(right: 4, top: 140, child: crest(3, 96)),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  new(this.rank);

  final int rank;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final metal = rankMetal(rank);
    Path shield(double inset) => Path()
      ..moveTo(w / 2, inset)
      ..quadraticBezierTo(w * .75, h * .08 + inset, w - inset, h * .1 + inset)
      ..lineTo(w - inset, h * .48)
      ..quadraticBezierTo(w - inset, h * .8, w / 2, h - inset)
      ..quadraticBezierTo(inset, h * .8, inset, h * .48)
      ..lineTo(inset, h * .1 + inset)
      ..quadraticBezierTo(w * .25, h * .08 + inset, w / 2, inset)
      ..close();
    canvas
      ..drawPath(
        shield(0).shift(const Offset(0, 4)),
        Paint()
          ..color = Colors.black.withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(
        shield(0),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: metal,
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        shield(5),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [KBrandColors.red500, Color(0xFF8A050C), Color(0xFF3A0508)],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        shield(9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = metal[0].withValues(alpha: .6),
      );
    // Top gem.
    final g = Offset(w / 2, 4);
    final gem = Path()
      ..moveTo(g.dx, g.dy - 7)
      ..lineTo(g.dx + 7, g.dy + 2)
      ..lineTo(g.dx, g.dy + 10)
      ..lineTo(g.dx - 7, g.dy + 2)
      ..close();
    canvas
      ..drawPath(gem, Paint()..color = const Color(0xFFFF4D5E))
      ..drawPath(
        gem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = metal[0],
      );
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => false;
}

class _BannerPainter extends CustomPainter {
  new(this.metal);

  final List<Color> metal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Tails.
    for (final left in [true, false]) {
      final x = left ? 0.0 : w;
      final d = left ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, 6)
          ..lineTo(x + d * 22, 6)
          ..lineTo(x + d * 22, h)
          ..lineTo(x, h)
          ..lineTo(x + d * 7, (h + 6) / 2)
          ..close(),
        Paint()..color = const Color(0xFF5A050C),
      );
    }
    final band = Path()
      ..moveTo(12, 0)
      ..quadraticBezierTo(w / 2, 6, w - 12, 0)
      ..lineTo(w - 12, h - 6)
      ..quadraticBezierTo(w / 2, h, 12, h - 6)
      ..close();
    canvas
      ..drawPath(
        band,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [KBrandColors.red500, KBrandColors.red700],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        band,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = metal[0],
      );
  }

  @override
  bool shouldRepaint(_BannerPainter old) => false;
}

// ---- rows and the «مركزي» bar ----------------------------------------------

class RankRow extends StatelessWidget {
  const new(this.e, {this.style, super.key});

  final LbEntry e;
  final LeaderboardStyle? style;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    return Container(
      height: 60,
      padding: const EdgeInsetsDirectional.only(start: 6, end: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.md + 2),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [Color(0xF2641019), Color(0xF23A060D)],
        ),
        border: Border.all(color: kGold.withValues(alpha: .35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${e.rank}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: KFonts.latin,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kGoldLight,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Avatar(e.photo, size: 40, ring: const [kGoldLight, kGoldDeep]),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: NameFlag(
              e,
              center: false,
              style: ts.bodyStrong.copyWith(color: Colors.white, height: 1.2),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          const CoinIcon(size: 16),
          const SizedBox(width: 4),
          Text(
            eventScore(e.score),
            style: const TextStyle(
              fontFamily: KFonts.latin,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kGoldLight,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A free place in the rows (fewer participants than places).
class OpenRow extends StatelessWidget {
  const new({required this.rank, super.key});

  final int rank;

  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    padding: const EdgeInsetsDirectional.only(start: 6, end: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.md + 2),
      color: const Color(0xCC2A0508),
      border: Border.all(color: kGold.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: KFonts.latin,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kGoldLight,
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kGold.withValues(alpha: .6)),
          ),
          child: Icon(Icons.person_rounded, color: kGold.withValues(alpha: .6)),
        ),
        const SizedBox(width: KSpacing.md),
        Text(
          context.l10n.eventsSeatOpen,
          style: context.textStyles.bodyStrong.copyWith(color: kGoldLight),
        ),
      ],
    ),
  );
}

/// The sticky «مركزي» bar of a designed page: gold, with wine text — the
/// caller's place, photo, the line [GiftEventMyBar] computes (rank and
/// score, or the final result) and its hint (what is missing, the prize).
class MyRankBar extends StatelessWidget {
  const new({required this.label, this.rank, this.photo, this.hint, super.key});

  final int? rank;
  final ImageProvider? photo;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    const ink = Color(0xFF2A0508);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsetsDirectional.only(
        start: 8,
        end: 14,
        top: 6,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFEDB3), kGold, Color(0xFFD9A23A)],
        ),
        border: Border.all(color: const Color(0xFFFFF6D6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 14,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              rank == null ? '–' : '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: KFonts.latin,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
          ),
          Avatar(
            photo,
            size: 42,
            ring: const [Colors.white, KBrandColors.red500],
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ts.bodyStrong.copyWith(
                    color: ink,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hint case final hint?)
                  Text(
                    hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ts.caption.copyWith(
                      color: const Color(0xFF5A1A0A),
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
