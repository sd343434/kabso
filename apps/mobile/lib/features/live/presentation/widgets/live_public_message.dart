import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D141 (owner's design `KabsoPublicMessage`, brought into the app): a
/// public message («رسالة عامة», CP-017 bullet) in the room chat, audio and
/// video — a dark glass card with a gold → red → pink edge, the gold
/// «📣 رسالة عامة» ribbon on its top edge with the shouting megaphone, the
/// sender's picture in a gold ring, their name in gold with the badges the
/// chat rows show (only what the room's chat already knows of them — never
/// a made-up level), the text (pack emoji play, as in the chat rows), the
/// time, and a faint megaphone in the corner.
///
/// Motion (not with reduced motion): it slides in from the reading start
/// and pops once, its glow pulses and a light sweeps across it; two light
/// streaks then run around the edge and the megaphone shouts every 2.4 s,
/// [loops] time(s) (the card stays in the chat; nothing loops for ever).
/// With reduced motion it is simply there, still. The owner's SVIP tier is
/// not brought over: Kabso has no SVIP.
///
/// A tap opens the sender's card ([onTap]).
class LivePublicMessage extends StatefulWidget {
  const new({
    required this.bullet,
    super.key,
    this.role,
    this.badges,
    this.onTap,
    this.maxWidth = 300,
  });

  final LiveBullet bullet;

  /// The sender's role and badges in this room, when the chat knows them.
  final LiveChatRole? role;
  final LiveChatAuthorBadges? badges;
  final VoidCallback? onTap;
  final double maxWidth;

  static Key keyFor(String id) => Key('liveChat.bullet.$id');

  /// How many rounds the edge streaks and the megaphone play after the
  /// card arrives.
  static const loops = 1;
  static const ribbonKey = Key('liveChat.bullet.ribbon');
  static const textKey = Key('liveChat.bullet.text');
  static const timeKey = Key('liveChat.bullet.time');

  /// The edge: gold → red → pink → gold.
  static const edge = [
    Color(0xFFFFE27A),
    Color(0xFFFF2D3A),
    Color(0xFFFF6FA5),
    Color(0xFFFFC93C),
  ];

  /// The card: wine → plum → night, from the reading start's top corner.
  static const fill = [Color(0xFF5A0A22), Color(0xFF2A0A2E), Color(0xFF1A0C2E)];
  static const glow = Color(0xFFFF2D3A);
  static const gold = [Color(0xFFFFF1B0), Color(0xFFFFC93C)];
  static const ribbon = [Color(0xFFFFE88A), Color(0xFFF0A81E)];
  static const ribbonInk = Color(0xFF4A2600);
  static const streak = Color(0xFFFF6FA5);

  @override
  State<LivePublicMessage> createState() => _LivePublicMessageState();
}

class _LivePublicMessageState extends State<LivePublicMessage>
    with TickerProviderStateMixin {
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _started = false;
  bool _flowStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _arrive.value = 1;
      _flow.stop();
      return;
    }
    if (!_started) {
      _started = true;
      _arrive.forward(from: 0);
    }
    if (!_flowStarted) {
      _flowStarted = true;
      unawaited(
        _flow.repeat(count: LivePublicMessage.loops).whenComplete(() {
          if (mounted) setState(() {});
        }),
      );
    }
  }

  @override
  void dispose() {
    _arrive.dispose();
    _flow.dispose();
    super.dispose();
  }

  static double _seg(double p, double a, double b) =>
      ((p - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bullet = widget.bullet;
    final name = bullet.sender.displayName;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final card = _card(context, reduced: reduced);
    return Semantics(
      button: widget.onTap != null,
      label: l10n.liveBulletLabel(name, kabiSpokenText(bullet.text, l10n)),
      excludeSemantics: true,
      child: GestureDetector(
        key: LivePublicMessage.keyFor(bullet.id),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _arrive,
          child: card,
          builder: (context, child) {
            final p = _arrive.value;
            final inT = Curves.easeOutBack.transform(_seg(p, 0, .35));
            final slide =
                (1 - Curves.easeOutCubic.transform(_seg(p, 0, .35))) *
                40 *
                (rtl ? 1 : -1);
            return Opacity(
              opacity: _seg(p, 0, .2),
              child: Transform.translate(
                offset: Offset(slide, 0),
                child: Transform.scale(
                  scale: .9 + .1 * inT,
                  alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required bool reduced}) {
    final l10n = context.l10n;
    final styles = context.textStyles;
    final bullet = widget.bullet;
    final name = bullet.sender.displayName;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final badges = LiveChatBadgeRow(
      role: widget.role,
      badges: widget.badges,
      height: LiveChatInlineRow.badgeHeight,
    );
    final local = bullet.createdAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    const textSize = 14.5;
    final body = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(11, 15, 13, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: name, imageUrl: bullet.sender.avatarUrl),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: LivePublicMessage.gold,
                        ).createShader(r),
                        child: Text(
                          KFormat.bidiIsolate(name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: scaler,
                          style: styles.caption.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontSize: 13.5,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Flexible(child: badges),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // CP-003 tokens play as the pack's emoji (D141: the owner saw
                // ":kiki_love:" written out here).
                KBidiRichText(
                  TextSpan(
                    style: styles.bodyStrong.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontSize: textSize,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      ...kabiIsolatedSpans(
                        bullet.text,
                        size: textSize * KKabiEmoji.inlineScale,
                      ),
                    ],
                  ),
                  key: LivePublicMessage.textKey,
                  textScaler: scaler,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    time,
                    key: LivePublicMessage.timeKey,
                    textDirection: TextDirection.ltr,
                    textScaler: scaler,
                    semanticsLabel: l10n.liveBulletTime(time),
                    style: styles.caption.copyWith(
                      color: const Color(0x80FFFFFF),
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final framed = AnimatedBuilder(
      animation: _arrive,
      builder: (context, child) {
        final p = _arrive.value;
        final pulse = reduced ? 0.0 : math.sin(math.pi * _seg(p, .2, .7));
        final sweep = reduced ? 1.0 : _seg(p, .3, .85);
        return Container(
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: LivePublicMessage.edge,
            ),
            boxShadow: [
              BoxShadow(
                color: LivePublicMessage.glow.withValues(
                  alpha: .3 + .3 * pulse,
                ),
                blurRadius: 14 + 10 * pulse,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.4),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: AlignmentDirectional.topStart.resolve(
                          Directionality.of(context),
                        ),
                        radius: 1.6,
                        colors: LivePublicMessage.fill,
                        stops: const [0, .55, 1],
                      ),
                    ),
                  ),
                ),
                const PositionedDirectional(
                  end: 6,
                  bottom: 2,
                  child: Opacity(
                    opacity: .1,
                    child: CustomPaint(
                      size: Size(46, 46),
                      painter: _MegaphoneMark(Color(0xFFFFFFFF)),
                    ),
                  ),
                ),
                if (sweep > 0 && sweep < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FractionalTranslation(
                        translation: Offset(-1.2 + 2.4 * sweep, 0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFFFFFF).withValues(alpha: 0),
                                const Color(0xFFFFFFFF).withValues(alpha: .22),
                                const Color(0xFFFFFFFF).withValues(alpha: 0),
                              ],
                              stops: const [.35, .5, .65],
                              transform: const GradientRotation(.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                child!,
              ],
            ),
          ),
        );
      },
      child: body,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Padding(
        // Room for the ribbon over the top edge.
        padding: const EdgeInsets.only(top: 11),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            framed,
            if (!reduced && _flow.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _flow,
                      builder: (context, _) => CustomPaint(
                        painter: _EdgeStreaks(
                          _flow.value,
                          LivePublicMessage.streak,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              top: -11,
              start: 16,
              child: _Ribbon(label: l10n.liveBulletTag, playing: !reduced),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const new({required this.label, required this.playing});

  final String label;
  final bool playing;

  @override
  Widget build(BuildContext context) => Container(
    key: LivePublicMessage.ribbonKey,
    padding: const EdgeInsetsDirectional.fromSTEB(6, 1, 10, 1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.pill),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: LivePublicMessage.ribbon,
      ),
      border: Border.all(color: const Color(0x8CFFFFFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 2),
          child: KShoutingMegaphone(
            size: 20,
            playing: playing,
            loops: LivePublicMessage.loops,
          ),
        ),
        Text(
          label,
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
          style: context.textStyles.caption.copyWith(
            color: LivePublicMessage.ribbonInk,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const new({required this.name, required this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    padding: const EdgeInsets.all(2),
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE27A), Color(0xFFE0A21A)],
      ),
    ),
    child: KAvatar(name: name, imageUrl: imageUrl, size: 36),
  );
}

/// The faint megaphone in the card's corner.
class _MegaphoneMark extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final fill = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(3, 10)
        ..lineTo(3, 14)
        ..quadraticBezierTo(3, 15, 4, 15)
        ..lineTo(6, 15)
        ..lineTo(11, 19)
        ..lineTo(11, 5)
        ..lineTo(6, 9)
        ..lineTo(4, 9)
        ..quadraticBezierTo(3, 9, 3, 10)
        ..close(),
      fill,
    );
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(
        Rect.fromCircle(center: const Offset(12, 12), radius: 4.3),
        -math.pi * .3,
        math.pi * .6,
        false,
        stroke,
      )
      ..drawArc(
        Rect.fromCircle(center: const Offset(12, 12), radius: 7.6),
        -math.pi * .32,
        math.pi * .64,
        false,
        stroke,
      );
  }

  @override
  bool shouldRepaint(_MegaphoneMark old) => old.color != color;
}

/// Two comet-like streaks of light running around the rounded edge.
class _EdgeStreaks extends CustomPainter {
  const new(this.t, this.glow);

  final double t;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(.8);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(17.2));
    final clear = glow.withValues(alpha: 0);
    final bright = glow.withValues(alpha: .9);
    const white = Color(0xFFFFFFFF);
    final shader = SweepGradient(
      colors: [clear, clear, bright, white, clear, clear, bright, white, clear],
      stops: const [0, .26, .4, .46, .5, .76, .9, .96, 1],
      transform: GradientRotation(2 * math.pi * t),
    ).createShader(rect);
    canvas
      ..drawRRect(
        rr,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawRRect(
        rr,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
  }

  @override
  bool shouldRepaint(_EdgeStreaks old) => old.t != t || old.glow != glow;
}

/// D141 (owner's design): a red and gold megaphone that "shouts" every
/// [period] — it pulls back, punches forward, sound waves ripple out and a
/// heart, a star and a «!» fly away from the text beside it (it points to
/// the reading start). Still (its resting frame) when [playing] is false or
/// with reduced motion. The effects paint outside its box.
class KShoutingMegaphone extends StatefulWidget {
  const new({
    super.key,
    this.size = 24,
    this.period = const Duration(milliseconds: 2400),
    this.playing = true,
    this.loops,
  });

  final double size;
  final Duration period;
  final bool playing;

  /// How many shouts (null: for as long as it plays).
  final int? loops;

  @override
  State<KShoutingMegaphone> createState() => _KShoutingMegaphoneState();
}

class _KShoutingMegaphoneState extends State<KShoutingMegaphone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  bool _played = false;

  void _sync() {
    final play = widget.playing && !MediaQuery.disableAnimationsOf(context);
    if (play && !_c.isAnimating && !_played) {
      _played = widget.loops != null;
      unawaited(
        _c.repeat(count: widget.loops).whenComplete(() {
          if (mounted) _c.value = 0;
        }),
      );
    } else if (!play && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KShoutingMegaphone old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Transform.flip(
            // The painter points right; in LTR the reading start is left.
            flipX: !rtl,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _ShoutPainter(_c.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShoutPainter extends CustomPainter {
  const new(this.t);

  final double t;

  static double _c01(double v) => v.clamp(0.0, 1.0);
  static double _seg(double p, double a, double b) => _c01((p - a) / (b - a));
  static double _bump(double p, double a, double b) =>
      math.sin(math.pi * _seg(p, a, b));
  static double _eo(double q) => 1 - math.pow(1 - q, 3).toDouble();

  static const _waves = [
    Color(0xFFFFE27A),
    Color(0xFFFF6FA5),
    Color(0xFFFF2D3A),
  ];
  static const _angles = [-.5, .05, .55];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final ant = _bump(t, .45, .58);
    final sh = _bump(t, .55, .72);
    final idle = math.sin(t * math.pi * 4) * .02;
    final q0 = _seg(t, .7, 1);
    final rot =
        -.28 * ant + .12 * sh + math.sin(q0 * math.pi * 3) * (1 - q0) * .06;
    final sc = 1 - .12 * ant + .16 * sh + idle;

    // Sound waves.
    for (var k = 0; k < 3; k++) {
      final q = _seg(t, .58 + k * .05, .9 + k * .05);
      if (q <= 0 || q >= 1) continue;
      final r = 4 + 9 * _eo(q);
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(15.5, 12), radius: r),
        -.55,
        1.1,
        false,
        Paint()
          ..color = _waves[k].withValues(alpha: (1 - q) * .95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - q * .5)
          ..strokeCap = StrokeCap.round,
      );
    }

    // A heart, a star and a «!» fly out.
    for (var i = 0; i < 3; i++) {
      final q = _seg(t, .6 + i * .03, .98);
      if (q <= 0 || q >= 1) continue;
      final d = 4 + 12 * _eo(q);
      final a = _c01(1 - q * q);
      canvas
        ..save()
        ..translate(
          16 + math.cos(_angles[i]) * d,
          12 + math.sin(_angles[i]) * d - 2 * q,
        )
        ..rotate(q * 2 * (i - 1))
        ..scale((q < .15 ? q / .15 : 1) * 1.1);
      if (i == 0) {
        canvas.drawPath(
          Path()
            ..moveTo(0, 1.6)
            ..cubicTo(-2.6, 0, -2, -2.3, 0, -.8)
            ..cubicTo(2, -2.3, 2.6, 0, 0, 1.6)
            ..close(),
          Paint()..color = const Color(0xFFFF2D3A).withValues(alpha: a),
        );
      } else if (i == 1) {
        final star = Path();
        for (var j = 0; j < 10; j++) {
          final rr = j.isOdd ? 1.0 : 2.4;
          final aa = -math.pi / 2 + j * math.pi / 5;
          final p = Offset(math.cos(aa) * rr, math.sin(aa) * rr);
          if (j == 0) {
            star.moveTo(p.dx, p.dy);
          } else {
            star.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(
          star..close(),
          Paint()..color = const Color(0xFFFFC93C).withValues(alpha: a),
        );
      } else {
        final w = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a);
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-1.9, -2.6, 3.8, 5.2),
              const Radius.circular(1.6),
            ),
            Paint()..color = const Color(0xFFFF2D3A).withValues(alpha: a),
          )
          ..drawRect(const Rect.fromLTWH(-.45, -1.8, .9, 2.2), w)
          ..drawRect(const Rect.fromLTWH(-.45, 1, .9, .8), w);
      }
      canvas.restore();
    }

    // The megaphone.
    canvas
      ..save()
      ..translate(8, 13)
      ..rotate(rot)
      ..scale(sc)
      ..translate(-8, -13)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(6.2, 14, 3, 5.2),
          const Radius.circular(1.3),
        ),
        Paint()..color = const Color(0xFF8A0008),
      )
      ..drawPath(
        Path()
          ..moveTo(3.4, 9.6)
          ..lineTo(15.2, 4.2)
          ..quadraticBezierTo(16.4, 3.8, 16.4, 5)
          ..lineTo(16.4, 19)
          ..quadraticBezierTo(16.4, 20.2, 15.2, 19.8)
          ..lineTo(3.4, 14.4)
          ..close(),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B73), Color(0xFFE0101C), Color(0xFF8A0008)],
            stops: [0, .45, 1],
          ).createShader(const Rect.fromLTRB(0, 4, 24, 20)),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1.6, 9, 3.2, 6),
          const Radius.circular(1.4),
        ),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1B0), Color(0xFFE0A21A)],
          ).createShader(const Rect.fromLTWH(1.6, 9, 3.2, 6)),
      )
      ..drawOval(
        Rect.fromCenter(
          center: const Offset(16.4, 12),
          width: 3.2,
          height: 15.2,
        ),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF1B0), Color(0xFFFFC93C), Color(0xFFB8780A)],
          ).createShader(const Rect.fromLTRB(15, 4, 18, 20)),
      )
      ..drawOval(
        Rect.fromCenter(
          center: const Offset(16.6, 12),
          width: 1.6,
          height: 11.6,
        ),
        Paint()..color = const Color(0xFF5A0006),
      )
      ..drawLine(
        const Offset(5.6, 9.4),
        const Offset(13.6, 5.9),
        Paint()
          ..color = const Color(0xB3FFFFFF)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ShoutPainter old) => old.t != t;
}
