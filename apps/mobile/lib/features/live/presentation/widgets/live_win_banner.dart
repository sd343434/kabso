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

// D159: the owner's win banner (`kabso_win_banner.dart`, revision 2,
// 2026-10-28), drawn in Kabso's live layer. The frames, the 3.5 s timeline,
// the rays, sweeps, pop, coin burst, count-up and sparkles are the owner's;
// the name, the gift, the label and the numbers are widgets (RTL, screen
// readers).

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

  /// The frames' gold (owner's name, ×N and coins colour).
  static const gold = Color(0xFFFFD86A);

  /// The owner's ×N gradient (the same in every tier; revision 2).
  static const numberColors = [
    Color(0xFFFFF8C8),
    Color(0xFFFFC830),
    Color(0xFFE07A00),
    Color(0xFFFFD860),
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

  /// The label of a ×[multiplier] win: its tier's, except ×1000 and more,
  /// «سوبر جاكبوت» / SUPER JACKPOT (owner, D159: as the MAX X celebration).
  static String labelOf(AppLocalizations l10n, int multiplier) =>
      multiplier >= 1000
      ? l10n.liveMaxXSuperJackpot
      : label(l10n, LuckyWinTier.of(multiplier));

  /// The tier's label: «فوز», «فوز كبير», «فوز ضخم», «جاكبوت».
  static String label(AppLocalizations l10n, LuckyWinTier tier) =>
      switch (tier) {
        LuckyWinTier.sapphire => l10n.liveWinTierWin,
        LuckyWinTier.ruby => l10n.liveLuckyBigWin,
        LuckyWinTier.amethyst => l10n.liveWinTierHuge,
        LuckyWinTier.onyx => l10n.liveMaxXJackpot,
      };
}

// D159 revision 2 (owner, 2026-10-28): the frame art is a medallion and a
// message bar, 1080×329; geometry as fractions of the image (owner's).
const double _aspect = 329 / 1080;
const double _mx = .186; // medallion centre x (of the width)
const double _my = .563; // medallion centre y (of the height)
const double _mr = .086; // medallion radius (of the width)
const double _pl = .325; // message panel
const double _pt = .408;
const double _pr = .893;
const double _pb = .712;

double _c01(double v) => v.clamp(0.0, 1.0);
double _seg(double t, double a, double b) => _c01((t - a) / (b - a));
double _eo(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _ei(double t) => t * t * t;
double _eob(double t) {
  const c = 1.6;
  return 1 +
      (c + 1) * math.pow(t - 1, 3).toDouble() +
      c * math.pow(t - 1, 2).toDouble();
}

/// The owner's 8-way text outline.
List<Shadow> _outline(Color c, double w) => [
  for (final o in const [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
    Offset(.7, .7),
    Offset(-.7, .7),
    Offset(.7, -.7),
    Offset(-.7, -.7),
  ])
    Shadow(color: c, offset: o * w),
];

/// [formatted] cut at the placeholders' sentinels `\u0001` / `\u0002`:
/// the plain text between them (slot null) and the slots (1, 2), in order.
List<(String, int?)> _pieces(String formatted) {
  final out = <(String, int?)>[];
  final buf = StringBuffer();
  for (final r in formatted.runes) {
    if (r == 1 || r == 2) {
      if (buf.isNotEmpty) out.add((buf.toString(), null));
      buf.clear();
      out.add(('', r));
    } else {
      buf.writeCharCode(r);
    }
  }
  if (buf.isNotEmpty) out.add((buf.toString(), null));
  return out;
}

/// D159 (owner: «الإطار الخاص بهدية المكسب غيّره واجعلها بهذا الشكل، وكل
/// مكسب له شكل معين»; revision 2, 2026-10-28): a lucky win announced over
/// the room in its tier's frame ([LuckyWinTier]) — a medallion with ×N and
/// the tier's label, and a message bar: «Oz Nabulsi أرسل عملة الحظ» /
/// «ربح ×100 وحصل على 17,500 🪙», the coins counting up. It replaces
/// D145e's centred gold card.
///
/// Motion (owner's 3.5 s timeline, [LiveGiftEffects.luckyTime]): slides in
/// from the reading start (0–0.5 s), rays turn behind the medallion and
/// sparkles twinkle from 0.35 s, light sweeps at 0.38 s and 2.1 s, ×N pops
/// and coins fly out of the medallion at 0.45 s, the coins count up
/// 0.6–1.4 s, it slides out toward the reading end 3.05–3.45 s. In Arabic
/// this is the owner's file as is (in from the right, the medallion at the
/// left end); in English the frame and its content are mirrored. With
/// reduced motion it shows still — no slide, rays, coins, sweep, pop or
/// sparkles, the whole amount at once — and fades out at the end. Never
/// takes taps; screen readers hear it once.
class LiveWinBanner extends StatefulWidget {
  const new({
    required this.win,
    super.key,
    this.giftName,
    this.width = maxWidth,
  });

  final LuckyWin win;

  /// The gift's name from the catalogue; null: «هدية» / "a gift".
  final String? giftName;

  /// The frame's width (its height follows the art: 329 / 1080).
  final double width;

  /// The banner's widest; it sits [top] under the safe area, below the
  /// room's header and clear of an audio room's first seats.
  static const double maxWidth = 300;
  static const double top = 56;

  /// The frame's height at [width].
  static double heightOf(double width) => width * _aspect;

  /// The width on a screen [screenWidth] wide (16 pt margins).
  static double widthOn(double screenWidth) =>
      math.min(maxWidth, screenWidth - 2 * KSpacing.lg);

  static const frameKey = Key('gift.lucky.frame');
  static const nameKey = Key('gift.lucky.name');
  static const giftKey = Key('gift.lucky.gift');
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
    final label = LuckyWinTierArt.labelOf(l10n, win.multiplier);
    final gift = widget.giftName ?? l10n.liveGiftGeneric;
    final still = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final screenW = MediaQuery.sizeOf(context).width;
    final w = widget.width;
    final h = LiveWinBanner.heightOf(w);
    final k = w / 370;
    // The owner's art reads right to left; English mirrors it.
    double x(double f) => (rtl ? f : 1 - f) * w;
    final m = Offset(x(_mx), _my * h);
    final mr = _mr * w;
    final panel = Rect.fromLTRB(
      math.min(x(_pl), x(_pr)),
      _pt * h,
      math.max(x(_pl), x(_pr)),
      _pb * h,
    );
    final total = LiveGiftEffects.luckyTime.inMilliseconds.toDouble();
    Widget frame = Image.asset(
      tier.frame,
      key: LiveWinBanner.frameKey,
      width: w,
      height: h,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      // A missing file must not break the room: the bar in its colours.
      errorBuilder: (_, _, _) => Center(
        child: Container(
          width: w * .9,
          height: panel.height,
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
    if (!rtl) frame = Transform.flip(flipX: true, child: frame);
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
            // Owner: in 0–0.5 s, out 3.05–3.45 s, from the reading start.
            final enter = still ? 1.0 : _eob(_seg(t, 0, 500));
            final exit = still ? 0.0 : _ei(_seg(t, 3050, 3450));
            final dx = ((1 - enter) - exit) * screenW * .95 * (rtl ? 1 : -1);
            final pop = still ? 1.0 : _seg(t, 450, 820);
            final flash = still ? 1.0 : _seg(t, 450, 950);
            final coins = still
                ? win.coinsWon
                : (win.coinsWon * _eo(_seg(t, 600, 1400))).round();
            final fade = still ? 1 - _seg(t, total - 400, total) : 1.0;
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
                          painter: _BackFxPainter(
                            t,
                            art.glow,
                            m,
                            mr,
                            still: still,
                            rtl: rtl,
                          ),
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
                      // The medallion: the flash, ×N and the tier's label.
                      if (flash < 1)
                        Positioned(
                          left: m.dx - mr * 1.8,
                          top: m.dy - mr * 1.8,
                          width: mr * 3.6,
                          height: mr * 3.6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                radius: .5 * (.15 + .85 * _eo(flash)),
                                colors: [
                                  const Color(0xFFFFF5C8)
                                      .withValues(alpha: 1 - flash),
                                  const Color(0x00FFC850),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: m.dx - mr * .9,
                        top: m.dy - mr * .78,
                        width: mr * 1.8,
                        height: mr * 1.2,
                        child: Opacity(
                          opacity: pop > 0 ? 1 : 0,
                          child: Transform.scale(
                            scale: 1 + 1.2 * (1 - _eob(pop)),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _Multiplier(
                                multiplier: win.multiplier,
                                k: k,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: m.dx - mr,
                        top: m.dy + mr * .5 - 7 * k,
                        width: mr * 2,
                        height: 14 * k,
                        child: Opacity(
                          opacity: still ? 1 : _seg(t, 650, 850),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                key: LiveWinBanner.labelKey,
                                maxLines: 1,
                                textScaler: TextScaler.noScaling,
                                style: context.textStyles.label.copyWith(
                                  fontSize: 8 * k,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  color: const Color(0xFF8A0A12),
                                  shadows: _outline(
                                    const Color(0xF2FFFAE6),
                                    1.1 * k,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!still) ..._coinBurst(m, mr, t, k, rtl: rtl),
                      // The message.
                      Positioned.fromRect(
                        rect: Rect.fromLTRB(
                          panel.left + panel.height * .5,
                          panel.top,
                          panel.right - panel.height * .5,
                          panel.bottom,
                        ),
                        child: Opacity(
                          opacity: still ? 1 : _seg(t, 380, 620),
                          child: _Message(
                            name: win.sender.displayName,
                            gift: gift,
                            multiplier: win.multiplier,
                            coins: coins,
                            k: k,
                          ),
                        ),
                      ),
                      if (!still)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SparklePainter(t, rtl: rtl),
                          ),
                        ),
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

  /// Coins flying out of the medallion (owner's `_coinBurst`).
  static List<Widget> _coinBurst(
    Offset m,
    double mr,
    double t,
    double k, {
    required bool rtl,
  }) {
    final out = <Widget>[];
    for (var i = 0; i < 9; i++) {
      final u = _seg(t, 470.0 + i * 14, 1250.0 + i * 14);
      if (u <= 0 || u >= 1) continue;
      final a = -math.pi * .15 - (i / 8) * math.pi * .7;
      final p = Offset(
        m.dx + (rtl ? 1 : -1) * math.cos(a) * mr * 3.2 * _eo(u),
        m.dy + math.sin(a) * mr * 2.2 * _eo(u) + mr * 2.4 * u * u,
      );
      final s = 12 * k;
      out.add(
        Positioned(
          left: p.dx - s / 2,
          top: p.dy - s / 2,
          width: s,
          height: s,
          child: Opacity(
            opacity: _c01(1 - u * u),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                .5 + .5 * math.cos(t / 90 + i).abs(),
                1,
                1,
              ),
              child: KabsoArtIcon(KabsoArt.coin, size: s),
            ),
          ),
        ),
      );
    }
    return out;
  }

  /// The owner's two light sweeps (0.38–1.05 s and 2.1–2.75 s).
  static Shader _sweep(Rect r, double t, {required bool rtl}) {
    double band(double a, double b) {
      final u = _seg(t, a, b);
      return (u > 0 && u < 1) ? u : -1;
    }

    final u = math.max(band(380, 1050), band(2100, 2750));
    if (u < 0) {
      return const LinearGradient(
        colors: [Color(0x00000000), Color(0x00000000)],
      ).createShader(r);
    }
    final c = -.25 + 1.5 * u;
    return LinearGradient(
      begin: Alignment(rtl ? -1 : 1, -.35),
      end: Alignment(rtl ? 1 : -1, .35),
      colors: const [Color(0x00FFFAE1), Color(0xB3FFFAE1), Color(0x00FFFAE1)],
      stops: [_c01(c - .07), _c01(c), _c01(c + .07)],
    ).createShader(r);
  }
}

class _Multiplier extends StatelessWidget {
  const new({required this.multiplier, required this.k});

  final int multiplier;
  final double k;

  @override
  Widget build(BuildContext context) {
    final text = '×${KFormat.grouped(multiplier)}';
    final style = context.textStyles.headline.copyWith(
      fontSize: 30 * k,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      letterSpacing: -.5,
    );
    // Digits and the sign read left to right in both languages; the
    // italic's overhang keeps inside the gradient's box.
    return Padding(
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
                ..strokeWidth = 6 * k
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF4A1600),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: LuckyWinTierArt.numberColors,
              stops: [0, .42, .58, 1],
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
    );
  }
}

/// The message bar's two lines: «{name} أرسل {gift}» (the name gold, cut
/// with an ellipsis in its own direction) and «ربح ×N وحصل على N 🪙» (×N
/// and the coins gold).
class _Message extends StatelessWidget {
  const new({
    required this.name,
    required this.gift,
    required this.multiplier,
    required this.coins,
    required this.k,
  });

  final String name;
  final String gift;
  final int multiplier;
  final int coins;
  final double k;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = context.textStyles.label;
    // The frame is art of a fixed size: the text follows the reader's
    // scale a little, never out of the bar.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
    final outline = _outline(const Color(0xD9280000), 1.2 * k);
    TextStyle s(double size, Color c, FontWeight weight) => base.copyWith(
      fontSize: size * k,
      color: c,
      fontWeight: weight,
      height: 1.15,
      shadows: outline,
    );
    const white = Color(0xFFFFFFFF);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sent = [
      for (final (text, slot) in _pieces(
        l10n.liveWinBannerSent('\u0001', '\u0002'),
      ))
        switch (slot) {
          1 => Flexible(
            flex: 3,
            child: Text(
              name,
              key: LiveWinBanner.nameKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: KFormat.firstStrongDirection(name),
              textAlign: rtl ? TextAlign.right : TextAlign.left,
              textScaler: scaler,
              style: s(11.5, LuckyWinTierArt.gold, FontWeight.w900),
            ),
          ),
          2 => Flexible(
            flex: 2,
            child: Text(
              gift,
              key: LiveWinBanner.giftKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler,
              style: s(11, white, FontWeight.w900),
            ),
          ),
          _ => Text(
            text,
            maxLines: 1,
            textScaler: scaler,
            style: s(11, white, FontWeight.w700),
          ),
        },
    ];
    final won = [
      for (final (text, slot) in _pieces(
        l10n.liveWinBannerWon('\u0001', '\u0002'),
      ))
        switch (slot) {
          1 => Text(
            '×${KFormat.grouped(multiplier)}',
            maxLines: 1,
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            style: s(12.5, LuckyWinTierArt.gold, FontWeight.w900),
          ),
          2 => Text(
            KFormat.grouped(coins),
            key: LiveWinBanner.coinsKey,
            maxLines: 1,
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            style: s(13, LuckyWinTierArt.gold, FontWeight.w900),
          ),
          _ => Text(
            text,
            maxLines: 1,
            textScaler: scaler,
            style: s(11, white, FontWeight.w700),
          ),
        },
      SizedBox(width: 3 * k),
      KabsoArtIcon(KabsoArt.coin, size: 15 * k),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: sent),
        SizedBox(height: k),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(mainAxisSize: MainAxisSize.min, children: won),
          ),
        ),
      ],
    );
  }
}

double _rnd(int i) {
  final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

/// Rays turning behind the medallion and the tier's breathing glow behind
/// the message bar (owner's `_BackFxPainter`). Still: the glow only.
class _BackFxPainter extends CustomPainter {
  const new(
    this.t,
    this.color,
    this.m,
    this.mr, {
    required this.still,
    required this.rtl,
  });

  final double t;
  final Color color;
  final Offset m;
  final double mr;
  final bool still;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final ra = still ? 0.0 : _seg(t, 350, 700);
    if (ra > 0) {
      final a = ra * (.55 + .2 * math.sin(t / 260));
      final len = mr * 2.5;
      final p = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .8 * a),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: len));
      canvas
        ..save()
        ..translate(m.dx, m.dy)
        ..rotate(t / 1600);
      for (var i = 0; i < 12; i++) {
        canvas
          ..rotate(math.pi / 6)
          ..drawPath(
            Path()
              ..moveTo(-mr * .12, 0)
              ..lineTo(-mr * .42, -len)
              ..lineTo(mr * .42, -len)
              ..lineTo(mr * .12, 0)
              ..close(),
            p,
          );
      }
      canvas.restore();
    }
    final ga = still ? .6 : (.6 + .25 * math.sin(t / 240)) * _seg(t, 200, 600);
    if (ga > 0) {
      final r = size.width * .5;
      canvas
        ..save()
        ..translate(size.width * (rtl ? .6 : .4), size.height * .56)
        ..scale(1, .35)
        ..drawCircle(
          Offset.zero,
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: .4 * ga),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_BackFxPainter old) =>
      old.t != t ||
      old.color != color ||
      old.m != m ||
      old.mr != mr ||
      old.still != still ||
      old.rtl != rtl;
}

/// Rising motes in the message bar, then a dim layer so the text reads on
/// every jewel.
class _PanelFxPainter extends CustomPainter {
  const new(this.t, {required this.still});

  final double t;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    if (!still) {
      final dot = Paint()..blendMode = BlendMode.plus;
      for (var i = 0; i < 16; i++) {
        final u = ((t / 2600) + _rnd(i)) % 1;
        dot.color = Color.fromRGBO(255, 235, 200, math.sin(u * math.pi) * .56);
        canvas.drawCircle(
          Offset(
            size.width * _rnd(i + 9) + 4 * math.sin(t / 400 + i),
            size.height * (1 - u),
          ),
          .6 + _rnd(i + 3) * .9,
          dot,
        );
      }
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x40000000),
    );
  }

  @override
  bool shouldRepaint(_PanelFxPainter old) => old.t != t || old.still != still;
}

const _tips = [
  Offset(.02, .18), Offset(0, .45), Offset(.05, .78), Offset(.29, .13), //
  Offset(.098, .02), Offset(.98, .18), Offset(1, .45), Offset(.95, .78), //
  Offset(.61, .06), Offset(.565, .9), Offset(.186, .94),
];

/// The sparkles twinkling on the frame (owner's `_SparklePainter`).
class _SparklePainter extends CustomPainter {
  const new(this.t, {required this.rtl});

  final double t;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final appear = _seg(t, 250, 500);
    if (appear <= 0) return;
    for (var i = 0; i < _tips.length; i++) {
      final tw = math.max<double>(0, math.sin(t / 330 + i * 1.9));
      if (tw < .15) continue;
      final s = 1.6 + tw * 1.7;
      final a = tw * appear;
      final dx = rtl ? _tips[i].dx : 1 - _tips[i].dx;
      canvas
        ..save()
        ..translate(dx * size.width, _tips[i].dy * size.height)
        ..drawCircle(
          Offset.zero,
          s * 2.2,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader =
                RadialGradient(
                  colors: [
                    Color.fromRGBO(255, 255, 240, a),
                    Color.fromRGBO(255, 230, 160, .6 * a),
                    const Color(0x00FFC864),
                  ],
                  stops: const [0, .25, 1],
                ).createShader(
                  Rect.fromCircle(center: Offset.zero, radius: s * 2.2),
                ),
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
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t || old.rtl != rtl;
}
