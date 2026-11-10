// KL-352 PROTOTYPE: reusable blocks for a block-built event page (the
// direction of the admin page builder). Each block takes admin data (texts,
// images, items) and the page theme; the ornaments are drawn here (gold
// gradients, simplified filigree), nothing traced from any reference.
//
// Catalogue (id → fields → theme tokens) — see the KL-352 report.

import 'dart:math' as math;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/presentation/event_concepts.dart';
import 'package:kabso_live/features/programs/presentation/event_leaderboard_styles.dart';
import 'package:material_ui/material_ui.dart';

/// The block page's theme (one per event; the admin picks a preset).
@immutable
class BlockTheme {
  const BlockTheme({
    this.page = kPageBg,
    this.gold = kGoldGradient,
    this.goldSolid = kGold,
    this.banner = const [KBrandColors.red500, KBrandColors.red700],
    this.title = kGoldLight,
    this.text = const Color(0xFFF3E6CF),
    this.muted = const Color(0xFFCDB89A),
  });

  final Color page;
  final Gradient gold;
  final Color goldSolid;
  final List<Color> banner;
  final Color title;
  final Color text;
  final Color muted;

  static const kabsoGold = BlockTheme();
}

const _bt = BlockTheme.kabsoGold;

// ---- hero ------------------------------------------------------------------

class EbHero extends StatelessWidget {
  const EbHero({
    required this.image,
    required this.title,
    this.subtitle,
    this.height = 430,
    super.key,
  });

  final ImageProvider image;
  final String title;
  final String? subtitle;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image(image: image, fit: BoxFit.cover, alignment: Alignment.topCenter),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0x59000000),
                const Color(0x00000000),
                _bt.page.withValues(alpha: .7),
                _bt.page,
              ],
              stops: const [0, .25, .78, 1],
            ),
          ),
        ),
        Positioned(
          left: KSpacing.lg,
          right: KSpacing.lg,
          bottom: 56,
          child: Column(
            children: [
              TitleArt(title, size: 44),
              if (subtitle != null) ...[
                const SizedBox(height: KSpacing.sm),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodyStrong.copyWith(
                    color: _bt.title,
                    shadows: const [
                      Shadow(color: Color(0xE6000000), blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ---- section title ---------------------------------------------------------

enum EbOrnament { crest, wings }

class EbSectionTitle extends StatelessWidget {
  const EbSectionTitle(
    this.text, {
    this.ornament = EbOrnament.crest,
    super.key,
  });

  final String text;
  final EbOrnament ornament;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      textAlign: TextAlign.center,
      style: context.textStyles.headline.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        height: 1.25,
        color: _bt.title,
        shadows: const [
          Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Column(
        children: [
          if (ornament == EbOrnament.crest)
            const SizedBox(
              width: 150,
              height: 38,
              child: CustomPaint(painter: _CrestPainter()),
            ),
          SizedBox(
            height: 50,
            child: CustomPaint(
              painter: _BannerStripPainter(ornament),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: label,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(
            width: 220,
            height: 12,
            child: CustomPaint(painter: _DividerPainter()),
          ),
        ],
      ),
    );
  }
}

Shader _goldShader(Rect r) => _bt.gold.createShader(r);

/// Simplified filigree: mirrored S-scrolls around a gem and a small crown.
class _CrestPainter extends CustomPainter {
  const _CrestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cx = w / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = _goldShader(Offset.zero & size);
    for (final d in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(cx + d * 12, h - 6)
        ..cubicTo(cx + d * 34, h - 4, cx + d * 40, h - 26, cx + d * 56, h - 22)
        ..cubicTo(cx + d * 68, h - 19, cx + d * 66, h - 6, cx + d * 58, h - 8)
        ..cubicTo(
          cx + d * 52,
          h - 10,
          cx + d * 56,
          h - 16,
          cx + d * 60,
          h - 14,
        );
      canvas.drawPath(p, stroke);
      final q = Path()
        ..moveTo(cx + d * 20, h - 12)
        ..cubicTo(
          cx + d * 30,
          h - 30,
          cx + d * 18,
          h - 34,
          cx + d * 14,
          h - 26,
        );
      canvas.drawPath(q, stroke..strokeWidth = 1.6);
      canvas.drawCircle(
        Offset(cx + d * 70, h - 12),
        2.2,
        Paint()..shader = _goldShader(Offset.zero & size),
      );
    }
    // Crown.
    final c = Path()
      ..moveTo(cx - 11, h - 16)
      ..lineTo(cx - 13, h - 30)
      ..lineTo(cx - 5, h - 23)
      ..lineTo(cx, h - 34)
      ..lineTo(cx + 5, h - 23)
      ..lineTo(cx + 13, h - 30)
      ..lineTo(cx + 11, h - 16)
      ..close();
    canvas.drawPath(c, Paint()..shader = _goldShader(Offset.zero & size));
    // Gem.
    final g = Path()
      ..moveTo(cx, h - 16)
      ..lineTo(cx + 7, h - 8)
      ..lineTo(cx, h)
      ..lineTo(cx - 7, h - 8)
      ..close();
    canvas.drawPath(g, Paint()..color = KBrandColors.red400);
    canvas.drawPath(
      g,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = _goldShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CrestPainter old) => false;
}

class _BannerStripPainter extends CustomPainter {
  const _BannerStripPainter(this.ornament);

  final EbOrnament ornament;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = Offset.zero & size;
    final band = Path();
    if (ornament == EbOrnament.crest) {
      band
        ..moveTo(18, 4)
        ..lineTo(w - 18, 4)
        ..lineTo(w - 2, h / 2)
        ..lineTo(w - 18, h - 4)
        ..lineTo(18, h - 4)
        ..lineTo(2, h / 2)
        ..close();
    } else {
      band.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(44, 4, w - 88, h - 8),
          const Radius.circular(8),
        ),
      );
    }
    canvas.drawPath(
      band.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _bt.banner,
        ).createShader(r),
    );
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..shader = _goldShader(r),
    );
    // Inner hairline.
    canvas.save();
    canvas.clipPath(band);
    canvas.drawRect(
      Rect.fromLTWH(0, 7, w, 1),
      Paint()..color = _bt.goldSolid.withValues(alpha: .35),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h - 8, w, 1),
      Paint()..color = _bt.goldSolid.withValues(alpha: .35),
    );
    canvas.restore();
    if (ornament == EbOrnament.wings) {
      // Feathered wings either side.
      final stroke = Paint()
        ..style = PaintingStyle.fill
        ..shader = _goldShader(r);
      for (final d in [-1.0, 1.0]) {
        final x0 = d < 0 ? 44.0 : w - 44;
        for (var i = 0; i < 4; i++) {
          final len = 30.0 - i * 5;
          final y = h / 2 - 10 + i * 6;
          final p = Path()
            ..moveTo(x0, y)
            ..quadraticBezierTo(
              x0 - d * len * .6,
              y - 8 + i * 2,
              x0 - d * len,
              y - 2 + i * 3,
            )
            ..quadraticBezierTo(x0 - d * len * .5, y + 1, x0, y + 4)
            ..close();
          canvas.drawPath(p, stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BannerStripPainter old) => false;
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, cy = size.height / 2;
    for (final d in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(w / 2 + d * 10, cy),
        Offset(w / 2 + d * w / 2, cy),
        Paint()
          ..strokeWidth = 1.2
          ..shader = LinearGradient(
            begin: d < 0 ? Alignment.centerRight : Alignment.centerLeft,
            end: d < 0 ? Alignment.centerLeft : Alignment.centerRight,
            colors: [_bt.goldSolid, _bt.goldSolid.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    final g = Path()
      ..moveTo(w / 2, cy - 5)
      ..lineTo(w / 2 + 6, cy)
      ..lineTo(w / 2, cy + 5)
      ..lineTo(w / 2 - 6, cy)
      ..close();
    canvas.drawPath(g, Paint()..shader = _goldShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(_DividerPainter old) => false;
}

// ---- paragraph -------------------------------------------------------------

class EbParagraph extends StatelessWidget {
  const EbParagraph(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: context.textStyles.body.copyWith(color: _bt.text, height: 1.6),
    ),
  );
}

// ---- icon grid -------------------------------------------------------------

@immutable
class EbIconItem {
  const EbIconItem(this.label, {this.asset, this.icon, this.round = false});

  final String label;
  final String? asset;
  final IconData? icon;

  /// Clip the asset to a circle (photos / the mascot avatar).
  final bool round;
}

class EbIconGrid extends StatelessWidget {
  const EbIconGrid(this.items, {super.key});

  final List<EbIconItem> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: 108,
                  height: 108,
                  child: CustomPaint(
                    painter: const _PedestalRingPainter(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: it.asset != null
                          ? (it.round
                                ? ClipOval(
                                    child: Image.asset(
                                      it.asset!,
                                      fit: BoxFit.cover,
                                      excludeFromSemantics: true,
                                    ),
                                  )
                                : Image.asset(
                                    it.asset!,
                                    fit: BoxFit.contain,
                                    excludeFromSemantics: true,
                                  ))
                          : FittedBox(
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: _goldShader,
                                child: Icon(it.icon, color: Colors.white),
                              ),
                            ),
                    ),
                  ),
                ),
                Container(
                  height: 50,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(KRadius.sm),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _bt.banner,
                    ),
                    border: Border.all(color: _bt.goldSolid, width: 1),
                  ),
                  child: Text(
                    it.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: context.textStyles.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// A glowing gold ring standing on a small oval pedestal.
class _PedestalRingPainter extends CustomPainter {
  const _PedestalRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2 - 8);
    final r = w / 2 - 14;
    // Base.
    final base = Rect.fromCenter(
      center: Offset(w / 2, h - 12),
      width: w * .78,
      height: 18,
    );
    canvas.drawOval(
      base.inflate(6),
      Paint()
        ..color = _bt.goldSolid.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawOval(
      base,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF7A4A14),
            _bt.goldSolid,
            const Color(0xFF7A4A14),
          ],
        ).createShader(base),
    );
    canvas.drawOval(
      base.deflate(3).shift(const Offset(0, -2)),
      Paint()..color = const Color(0xFF3A0508),
    );
    // Glow + disc + ring.
    canvas.drawCircle(
      c,
      r + 6,
      Paint()
        ..color = _bt.goldSolid.withValues(alpha: .4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF7A1420), Color(0xFF2A0508)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = _goldShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _bt.goldSolid.withValues(alpha: .5),
    );
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + i * math.pi / 2;
      paintSparkle(
        canvas,
        c + Offset(math.cos(a), math.sin(a)) * r,
        4,
        const Color(0xFFFFF4CF),
      );
    }
  }

  @override
  bool shouldRepaint(_PedestalRingPainter old) => false;
}

// ---- framed rewards box ----------------------------------------------------

@immutable
class EbRewardItem {
  const EbRewardItem(this.caption, this.art, {this.frameRank});

  final String caption;
  final String? art;

  /// Show a sample avatar inside the live-top frame of this rank.
  final int? frameRank;
}

class EbRewardsBox extends StatelessWidget {
  const EbRewardsBox({required this.title, required this.items, super.key});

  final String title;
  final List<EbRewardItem> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
    child: CustomPaint(
      painter: const _OrnateFramePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              width: 240,
              child: CustomPaint(
                painter: const _BannerStripPainter(EbOrnament.crest),
                child: Center(
                  child: Text(
                    title,
                    style: context.textStyles.title.copyWith(
                      color: _bt.title,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: KSpacing.md),
                  Expanded(child: _RewardBoxTile(items[i])),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _RewardBoxTile extends StatelessWidget {
  const _RewardBoxTile(this.item);

  final EbRewardItem item;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.lg),
            gradient: _bt.gold,
            boxShadow: [
              BoxShadow(
                color: _bt.goldSolid.withValues(alpha: .3),
                blurRadius: 12,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.lg - 2),
              gradient: const RadialGradient(
                colors: [Color(0xFF8A1A24), Color(0xFF2A050B)],
              ),
            ),
            padding: const EdgeInsets.all(KSpacing.sm),
            child: item.frameRank != null
                ? LayoutBuilder(
                    builder: (_, c) =>
                        TopFrame(item.frameRank!, null, size: c.maxWidth),
                  )
                : Image.asset(item.art!, excludeFromSemantics: true),
          ),
        ),
      ),
      const SizedBox(height: KSpacing.sm),
      Text(
        item.caption,
        textAlign: TextAlign.center,
        style: context.textStyles.label.copyWith(
          color: _bt.text,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    ],
  );
}

class _OrnateFramePainter extends CustomPainter {
  const _OrnateFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(
      r.deflate(2),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2420810), Color(0xF21A0306)],
        ).createShader(r),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = _goldShader(r),
    );
    canvas.drawRRect(
      outer.deflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _bt.goldSolid.withValues(alpha: .55),
    );
    // Corner flourishes.
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = _goldShader(r);
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (size.width, 0.0, -1.0, 1.0),
      (0.0, size.height, 1.0, -1.0),
      (size.width, size.height, -1.0, -1.0),
    ]) {
      final o = Offset(x + dx * 10, y + dy * 10);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx + dx * 30, o.dy)
          ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + dy * 30),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(o.dx + dx * 14, o.dy + dy * 4)
          ..cubicTo(
            o.dx + dx * 22,
            o.dy + dy * 14,
            o.dx + dx * 8,
            o.dy + dy * 20,
            o.dx + dx * 4,
            o.dy + dy * 14,
          ),
        p,
      );
      final g = Offset(x + dx * 7, y + dy * 7);
      canvas.drawPath(
        Path()
          ..moveTo(g.dx, g.dy - 5)
          ..lineTo(g.dx + 5, g.dy)
          ..lineTo(g.dx, g.dy + 5)
          ..lineTo(g.dx - 5, g.dy)
          ..close(),
        Paint()..color = KBrandColors.red400,
      );
    }
  }

  @override
  bool shouldRepaint(_OrnateFramePainter old) => false;
}

// ---- steps, notes, CTA, footer ---------------------------------------------

class EbSteps extends StatelessWidget {
  const EbSteps(this.steps, {super.key});

  final List<(String, String)> steps;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _bt.gold,
                          boxShadow: [
                            BoxShadow(
                              color: _bt.goldSolid.withValues(alpha: .4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontFamily: KFonts.latin,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: kWine,
                          ),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: _bt.goldSolid.withValues(alpha: .35),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: KSpacing.lg,
                        top: 3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].$1,
                            style: ts.bodyStrong.copyWith(
                              color: _bt.title,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            steps[i].$2,
                            style: ts.body.copyWith(
                              color: _bt.text,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
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

class EbNotes extends StatelessWidget {
  const EbNotes({required this.title, required this.lines, super.key});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.lg),
        color: const Color(0x99000000),
        border: Border.all(color: _bt.goldSolid.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: _bt.goldSolid),
              const SizedBox(width: 6),
              Text(title, style: ts.bodyStrong.copyWith(color: _bt.title)),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _bt.goldSolid,
                      ),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(
                      l,
                      style: ts.label.copyWith(
                        color: _bt.muted,
                        fontWeight: FontWeight.w400,
                        height: 1.55,
                      ),
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

class EbCta extends StatelessWidget {
  const EbCta(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
    child: Container(
      height: KSizes.buttonHeight + 4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF0B8), kGold, Color(0xFFC88E2C)],
        ),
        border: Border.all(color: const Color(0xFFFFF6D6), width: 1.4),
        boxShadow: [
          BoxShadow(color: kGold.withValues(alpha: .45), blurRadius: 18),
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: context.textStyles.title.copyWith(
          color: kWine,
          fontWeight: FontWeight.w900,
          fontSize: 19,
        ),
      ),
    ),
  );
}

/// Footer: slogan between ornamental lines, then the Kabso Live wordmark
/// (set in Fredoka like the launch screen; the official logo file is still
/// missing, blocker B8).
class EbFooter extends StatelessWidget {
  const EbFooter(this.slogan, {super.key});

  final String slogan;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          const SizedBox(width: KSpacing.xl),
          const Expanded(
            child: SizedBox(
              height: 12,
              child: CustomPaint(painter: _DividerPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
            child: Text(
              slogan,
              style: context.textStyles.bodyStrong.copyWith(color: _bt.title),
            ),
          ),
          const Expanded(
            child: SizedBox(
              height: 12,
              child: CustomPaint(painter: _DividerPainter()),
            ),
          ),
          const SizedBox(width: KSpacing.xl),
        ],
      ),
      const SizedBox(height: KSpacing.lg),
      Semantics(
        label: 'Kabso Live',
        child: ExcludeSemantics(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'kabso',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 34,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: KBrandColors.red500,
                    borderRadius: BorderRadius.circular(KRadius.sm),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
