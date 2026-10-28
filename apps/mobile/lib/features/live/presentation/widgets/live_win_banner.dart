import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// D159: the owner's win banner (`kabso_win_banner.dart`, 2026-10-28), drawn
// in Kabso's live layer. The frames, the 3.2 s timeline, the sweeps, the
// pop, the count-up and the wing-tip sparkles are the owner's; the avatar,
// the name, the label and the numbers are widgets (RTL, screen readers).

/// The colours of one [LuckyWinTier], sampled from its frame: the glow
/// (owner's `_tierGlow`) and the jewel panel's top and bottom. The MAX X
/// celebration and its winnings chip use them so every win of a tier looks
/// like its frame.
@immutable
class LuckyWinTierArt {
  const new(this.glow, this.panelTop, this.panelBottom);

  final Color glow;
  final Color panelTop;
  final Color panelBottom;

  /// The frames' gold (owner's label colour and the avatar's ring).
  static const gold = Color(0xFFFFD86A);

  /// The owner's ×N gradient (the same in every tier).
  static const numberColors = [
    Color(0xFFFFFDE8),
    Color(0xFFFFD54A),
    Color(0xFFF09A00),
    Color(0xFFFFE89A),
  ];

  static const _sapphire = LuckyWinTierArt(
    Color(0xFF4FA3FF),
    Color(0xFF0255BE),
    Color(0xFF01214D),
  );
  static const _ruby = LuckyWinTierArt(
    Color(0xFFFF3B4A),
    Color(0xFFB00102),
    Color(0xFF480000),
  );
  static const _amethyst = LuckyWinTierArt(
    Color(0xFFC77DFF),
    Color(0xFF7C01BC),
    Color(0xFF33004C),
  );
  static const _onyx = LuckyWinTierArt(
    Color(0xFFFFD54A),
    Color(0xFF504444),
    Color(0xFF211C1B),
  );

  static LuckyWinTierArt of(LuckyWinTier tier) => switch (tier) {
    LuckyWinTier.sapphire => _sapphire,
    LuckyWinTier.ruby => _ruby,
    LuckyWinTier.amethyst => _amethyst,
    LuckyWinTier.onyx => _onyx,
  };

  /// The tier's label: «فوز», «فوز كبير», «فوز ضخم», «جاكبوت».
  static String label(AppLocalizations l10n, LuckyWinTier tier) =>
      switch (tier) {
        LuckyWinTier.sapphire => l10n.liveWinTierWin,
        LuckyWinTier.ruby => l10n.liveLuckyBigWin,
        LuckyWinTier.amethyst => l10n.liveWinTierHuge,
        LuckyWinTier.onyx => l10n.liveMaxXJackpot,
      };
}

// The frame's inner panel, as fractions of the image (owner's values).
const double _pl = .1747;
const double _pt = .410;
const double _pr = .8257;
const double _pb = .732;
const double _aspect = 318 / 1080;

double _c01(double v) => v.clamp(0.0, 1.0);
double _seg(double t, double a, double b) => _c01((t - a) / (b - a));
double _eo(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _ei(double t) => t * t * t;
double _eob(double t) {
  const c = 1.5;
  return 1 +
      (c + 1) * math.pow(t - 1, 3).toDouble() +
      c * math.pow(t - 1, 2).toDouble();
}

/// D159 (owner: «الإطار الخاص بهدية المكسب غيّره… وكل مكسب له شكل معين»): a
/// lucky win announced over the room in its tier's frame ([LuckyWinTier]):
/// the winner's avatar, name and the tier's label, ×N, and the coins won
/// counting up. It replaces D145e's centred gold card.
///
/// Motion (owner's 3.2 s timeline, [LiveGiftEffects.luckyTime]): slides in
/// from the reading start (the right in Arabic, as the owner's file; the
/// left in English), a light sweep, ×N pops, the coins count up, a second
/// sweep, then it slides out to the reading end; the glow breathes and the
/// wing tips sparkle the whole time. With reduced motion it shows still —
/// the whole amount at once, no slide, sweep, pop or sparkles — and fades
/// out at the end. Never takes taps; screen readers hear it once.
class LiveWinBanner extends StatefulWidget {
  const new({required this.win, super.key, this.width = maxWidth});

  final LuckyWin win;

  /// The frame's width (its height follows the art: 318 / 1080).
  final double width;

  /// The banner's widest; it sits [top] under the safe area, below the
  /// room's header and clear of an audio room's first seats.
  static const double maxWidth = 300;
  static const double top = 57;

  /// The frame's height at [width].
  static double heightOf(double width) => width * _aspect;

  /// The width on a screen [screenWidth] wide (16 pt margins).
  static double widthOn(double screenWidth) =>
      math.min(maxWidth, screenWidth - 2 * KSpacing.lg);

  static const frameKey = Key('gift.lucky.frame');
  static const nameKey = Key('gift.lucky.name');
  static const labelKey = Key('gift.lucky.label');
  static const numberKey = Key('gift.lucky.number');
  static const coinsKey = Key('gift.lucky.coins');

  @override
  State<LiveWinBanner> createState() => _LiveWinBannerState();
}

class _LiveWinBannerState extends State<LiveWinBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: LiveGiftEffects.luckyTime,
    // With reduced motion the still banner stays as long (then fades).
    animationBehavior: AnimationBehavior.preserve,
  )..forward();

  LuckyWinTier get _tier => LuckyWinTier.of(widget.win.multiplier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(
      precacheImage(AssetImage(_tier.frame), context, onError: (_, _) {}),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final win = widget.win;
    final tier = _tier;
    final art = LuckyWinTierArt.of(tier);
    final label = LuckyWinTierArt.label(l10n, tier);
    final still = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final screenW = MediaQuery.sizeOf(context).width;
    final w = widget.width;
    final h = LiveWinBanner.heightOf(w);
    final k = w / 340;
    final panel = Rect.fromLTRB(_pl * w, _pt * h, _pr * w, _pb * h);
    final total = LiveGiftEffects.luckyTime.inMilliseconds.toDouble();
    final frame = Image.asset(
      tier.frame,
      key: LiveWinBanner.frameKey,
      width: w,
      height: h,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      // A missing file must not break the room: the panel in its colours.
      errorBuilder: (_, _, _) => Center(
        child: Container(
          width: panel.width + 8 * k,
          height: panel.height + 8 * k,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(panel.height),
            border: Border.all(color: LuckyWinTierArt.gold, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [art.panelTop, art.panelBottom],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      excludeSemantics: true,
      label: l10n.liveWinBannerSemantics(
        label,
        KFormat.bidiIsolate(win.sender.displayName),
        KFormat.grouped(win.multiplier),
        KFormat.bidiIsolate('+${KFormat.grouped(win.coinsWon)}'),
      ),
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * total;
            // Owner: in 0–0.48 s, out 2.75–3.15 s, from the reading start.
            final enter = still ? 1.0 : _eob(_seg(t, 0, 480));
            final exit = still ? 0.0 : _ei(_seg(t, 2750, 3150));
            final dx = ((1 - enter) - exit) * screenW * .9 * (rtl ? 1 : -1);
            final contentA = still ? 1.0 : _seg(t, 300, 520);
            final pop = still ? 1.0 : _seg(t, 420, 780);
            final coinsA = still ? 1.0 : _seg(t, 480, 650);
            final coins = still
                ? win.coinsWon
                : (win.coinsWon * _eo(_seg(t, 520, 1300))).round();
            final fade = still ? 1 - _seg(t, total - 400, total) : 1.0;
            final content = Positioned.fromRect(
              rect: panel.deflate(2 * k),
              child: Row(
                children: [
                  Opacity(
                    opacity: contentA,
                    child: _Avatar(win: win, size: panel.height - 6 * k, k: k),
                  ),
                  SizedBox(width: 5 * k),
                  Flexible(
                    flex: 3,
                    child: Opacity(
                      opacity: contentA,
                      child: _NameAndLabel(
                        name: win.sender.displayName,
                        label: label,
                        k: k,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      // Laid out from the start (the row keeps its
                      // place), shown when it pops.
                      child: Opacity(
                        opacity: pop > 0 ? 1 : 0,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Multiplier(
                            multiplier: win.multiplier,
                            pop: pop,
                            flash: still ? 1 : _seg(t, 420, 900),
                            k: k,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 4,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Opacity(
                        opacity: coinsA,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Coins(coins: coins, k: k),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
            return Opacity(
              opacity: fade,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GlowPainter(art.glow, t, still: still),
                        ),
                      ),
                      Positioned.fill(
                        child: still
                            ? frame
                            : ShaderMask(
                                blendMode: BlendMode.srcATop,
                                shaderCallback: (r) => _sweep(r, t, rtl: rtl),
                                child: frame,
                              ),
                      ),
                      Positioned.fromRect(
                        rect: panel,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(panel.height / 2),
                          child: CustomPaint(
                            painter: _PanelFxPainter(t, still: still),
                          ),
                        ),
                      ),
                      if (!still)
                        Positioned.fill(
                          child: CustomPaint(painter: _TipsPainter(t)),
                        ),
                      content,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The owner's two light sweeps (0.35–1.0 s and 1.9–2.55 s), across the
  /// frame from the reading start.
  static Shader _sweep(Rect r, double t, {required bool rtl}) {
    double band(double a, double b) {
      final u = _seg(t, a, b);
      return (u > 0 && u < 1) ? u : -1;
    }

    final u = math.max(band(350, 1000), band(1900, 2550));
    if (u < 0) {
      return const LinearGradient(
        colors: [Color(0x00000000), Color(0x00000000)],
      ).createShader(r);
    }
    final c = -0.25 + 1.5 * u;
    return LinearGradient(
      begin: Alignment(rtl ? 1 : -1, -.35),
      end: Alignment(rtl ? -1 : 1, .35),
      colors: const [Color(0x00FFFAE1), Color(0xBFFFFAE1), Color(0x00FFFAE1)],
      stops: [_c01(c - .07), _c01(c), _c01(c + .07)],
    ).createShader(r);
  }
}

class _Avatar extends StatelessWidget {
  const new({required this.win, required this.size, required this.k});

  final LuckyWin win;
  final double size;
  final double k;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(1.6 * k),
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: LuckyWinTierArt.gold,
    ),
    child: KAvatar(
      name: win.sender.displayName,
      imageUrl: win.sender.avatarUrl,
      size: size - 3.2 * k,
    ),
  );
}

class _NameAndLabel extends StatelessWidget {
  const new({required this.name, required this.label, required this.k});

  final String name;
  final String label;
  final double k;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    // The frame is art of a fixed size: the text follows the reader's
    // scale a little, never out of the panel.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The display name only (never the @username), in its own
        // direction (a Latin name in Arabic is cut at its end, «Oz Na…»),
        // kept at the reading start beside the avatar.
        Text(
          name,
          key: LiveWinBanner.nameKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: KFormat.firstStrongDirection(name),
          textAlign: Directionality.of(context) == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.left,
          textScaler: scaler,
          style: styles.label.copyWith(
            color: const Color(0xFFFFFFFF),
            fontSize: 10 * k,
            fontWeight: FontWeight.w700,
            height: 1.15,
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
          ),
        ),
        Text(
          label,
          key: LiveWinBanner.labelKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: scaler,
          style: styles.label.copyWith(
            color: LuckyWinTierArt.gold,
            fontSize: 8 * k,
            fontWeight: FontWeight.w900,
            height: 1.15,
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
          ),
        ),
      ],
    );
  }
}

class _Multiplier extends StatelessWidget {
  const new({
    required this.multiplier,
    required this.pop,
    required this.flash,
    required this.k,
  });

  final int multiplier;
  final double pop;
  final double flash;
  final double k;

  @override
  Widget build(BuildContext context) {
    final text = '×${KFormat.grouped(multiplier)}';
    final style = context.textStyles.headline.copyWith(
      fontSize: 24 * k,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      letterSpacing: -.5,
    );
    final d = (16 + 80 * _eo(flash)) * k;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (flash < 1)
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFF0BE).withValues(alpha: .9 * (1 - flash)),
                  const Color(0x00FFC850),
                ],
              ),
            ),
          ),
        Transform.scale(
          scale: 1 + 1.1 * (1 - _eob(pop)),
          // Digits and the sign read left to right in both languages; the
          // italic's overhang keeps inside the gradient's box.
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 3 * k),
            child: Stack(
              children: [
                Text(
                  text,
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  textScaler: TextScaler.noScaling,
                  style: style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 4 * k
                      ..strokeJoin = StrokeJoin.round
                      ..color = const Color(0xFF3A1200),
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: LuckyWinTierArt.numberColors,
                    stops: [0, .45, .6, 1],
                  ).createShader(r),
                  child: Text(
                    text,
                    key: LiveWinBanner.numberKey,
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    textScaler: TextScaler.noScaling,
                    style: style.copyWith(color: const Color(0xFFFFFFFF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Coins extends StatelessWidget {
  const new({required this.coins, required this.k});

  final int coins;
  final double k;

  @override
  Widget build(BuildContext context) {
    final text = '+${KFormat.grouped(coins)}';
    final style = context.textStyles.title.copyWith(
      fontSize: 14 * k,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        KabsoArtIcon(KabsoArt.coin, size: 20 * k),
        SizedBox(width: 3 * k),
        Stack(
          children: [
            Text(
              text,
              maxLines: 1,
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.noScaling,
              style: style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3.2 * k
                  ..color = const Color(0xE6280000),
              ),
            ),
            Text(
              text,
              key: LiveWinBanner.coinsKey,
              maxLines: 1,
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.noScaling,
              style: style.copyWith(color: const Color(0xFFFFFFFF)),
            ),
          ],
        ),
      ],
    );
  }
}

double _rnd(int i) {
  final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

/// The breathing glow of the tier's colour behind the frame.
class _GlowPainter extends CustomPainter {
  const new(this.color, this.t, {required this.still});

  final Color color;
  final double t;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final a = still ? .55 : (.55 + .25 * math.sin(t / 240)) * _seg(t, 200, 600);
    if (a <= 0) return;
    final c = size.center(Offset.zero);
    final r = size.width * .6;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(1, .42)
      ..drawCircle(
        Offset.zero,
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .44 * a),
              color.withValues(alpha: .13 * a),
              color.withValues(alpha: 0),
            ],
            stops: const [0, .6, 1],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.t != t || old.color != color || old.still != still;
}

/// Rising motes and a soft band across the panel, then a dim layer so the
/// text reads on every jewel.
class _PanelFxPainter extends CustomPainter {
  const new(this.t, {required this.still});

  final double t;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (!still) {
      final dot = Paint()..blendMode = BlendMode.plus;
      for (var i = 0; i < 14; i++) {
        final u = ((t / 2600) + _rnd(i)) % 1;
        final a = math.sin(u * math.pi) * .8;
        dot.color = Color.fromRGBO(255, 235, 200, a * .7);
        canvas.drawCircle(
          Offset(w * _rnd(i + 9) + 4 * math.sin(t / 400 + i), h * (1 - u)),
          .6 + _rnd(i + 3) * .9,
          dot,
        );
      }
      final ph = (t / 1400) % 1;
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            colors: const [
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
              Color(0x1FFFFFFF),
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, _c01(ph - .1), _c01(ph), _c01(ph + .1), 1],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x38000000),
    );
  }

  @override
  bool shouldRepaint(_PanelFxPainter old) => old.t != t || old.still != still;
}

const _tips = [
  Offset(.03, .12), Offset(0, .3), Offset(.05, .62), Offset(.16, .92), //
  Offset(.97, .12), Offset(1, .3), Offset(.95, .62), Offset(.84, .92), //
  Offset(.5, .03), Offset(.5, .97), Offset(.13, .46), Offset(.87, .46),
];

/// The sparkles twinkling at the wing tips (owner's `_TipsPainter`).
class _TipsPainter extends CustomPainter {
  const new(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final appear = _seg(t, 250, 500);
    if (appear <= 0) return;
    for (var i = 0; i < _tips.length; i++) {
      final tw = math.max<double>(0, math.sin(t / 330 + i * 1.9));
      if (tw < .15) continue;
      _star(
        canvas,
        Offset(_tips[i].dx * size.width, _tips[i].dy * size.height),
        1.6 + tw * 1.6,
        tw * appear,
      );
    }
  }

  void _star(Canvas c, Offset p, double s, double a) {
    c
      ..save()
      ..translate(p.dx, p.dy)
      ..drawCircle(
        Offset.zero,
        s * 2.2,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 255, 240, a),
              Color.fromRGBO(255, 230, 160, .6 * a),
              const Color(0x00FFC864),
            ],
            stops: const [0, .25, 1],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 2.2)),
      )
      ..drawPath(
        Path()
          ..moveTo(0, -s * 2.4)
          ..lineTo(s * .22, 0)
          ..lineTo(0, s * 2.4)
          ..lineTo(-s * .22, 0)
          ..close()
          ..moveTo(-s * 2.4, 0)
          ..lineTo(0, s * .22)
          ..lineTo(s * 2.4, 0)
          ..lineTo(0, -s * .22)
          ..close(),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_TipsPainter old) => old.t != t;
}
