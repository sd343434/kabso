import 'dart:math' as math;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_ref_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D304 (owner: «استنسخ التصميم ١٠٠٪ بدون تغير», with a reference screenshot
/// kept out of git): the «شراء VIP» page's parts in the reference's layout —
/// a carousel of tier cards (the selected one centred, its neighbours
/// peeking), thin gold arcs behind them and a gold curved divider under
/// them, the «امتيازات VIP» header with its count line, and a 2-column grid
/// of gold hexagons. Every shape is drawn here in code; the name, the badge
/// art, the icons and the texts are Kabso's (the reference's art, wordmark
/// and icons are not copied).
///
/// Measures are the reference's in pt at 393 wide (1.873 px/pt, estimated
/// from its 736 px width); see the D304 spec in the board.
abstract final class KVipRef {
  /// The page: a deep navy at the top fading into the dark plum below.
  static const Color pageTop = Color(0xFF111121);
  static const Color page = Color(0xFF1A1820);

  /// The card: 300 × 147 pt with a 31.5 pt gap to its neighbours.
  static const double cardWidth = 300;
  static const double cardHeight = 147.4;
  static const double cardGap = 31.5;
  static const double cardRadius = 13;

  /// The fraction of the screen width one page of the carousel takes.
  static const double viewportFraction = (cardWidth + cardGap) / 393;

  /// The gold divider: its ends this far under the cards, its middle lower.
  static const double dividerEnd = 6.3;
  static const double dividerMiddle = 25.5;

  /// The card bottom → the header's text box.
  static const double headerGap = 37;

  /// The header → the count line, the count line → the first hexagon.
  static const double countGap = 9;
  static const double gridGap = 20;

  /// A hexagon (pointy top), the label under it, and the row pitch.
  static const double hexWidth = 41;
  static const double hexHeight = 48.6;
  static const double labelGap = 10;
  static const double rowGap = 42;

  /// Golds (measured on the reference).
  static const Color gold = Color(0xFFF5E1B0);
  static const Color goldLine = Color(0xFFE6C873);
  static const Color goldDeep = Color(0xFFB8893A);
  static const Color countText = Color(0xFFE9E4C8);
  static const Color countLine = Color(0xFF8C7F5C);
}

/// The tier cards: one page per tier (VIP 1 at the reading start), the
/// selected one centred; a swipe or a tap on a neighbour selects it.
class VipTierCarousel extends StatefulWidget {
  const new({
    required this.tiers,
    required this.selectedId,
    required this.onSelect,
    required this.captionOf,
    this.ownedId,
    this.lockedIds = const {},
    super.key,
  });

  final List<VipTier> tiers;
  final String selectedId;
  final ValueChanged<VipTier> onSelect;

  /// The one line at the card's bottom (the price and length, or the
  /// member's end date).
  final String Function(VipTier tier) captionOf;

  /// The caller's active tier.
  final String? ownedId;

  /// The tiers below the caller's active one (dimmed).
  final Set<String> lockedIds;

  static const carouselKey = Key('vip.carousel');

  @override
  State<VipTierCarousel> createState() => _VipTierCarouselState();
}

class _VipTierCarouselState extends State<VipTierCarousel> {
  late final PageController _pages = PageController(
    initialPage: _indexOf(widget.selectedId),
    viewportFraction: KVipRef.viewportFraction,
  );

  int _indexOf(String id) =>
      math.max(0, widget.tiers.indexWhere((t) => t.id == id));

  @override
  void didUpdateWidget(VipTierCarousel old) {
    super.didUpdateWidget(old);
    final target = _indexOf(widget.selectedId);
    if (!_pages.hasClients) return;
    final at = _pages.page?.round() ?? target;
    // Selected from outside (a reload, a membership): bring it to the middle.
    if (at != target && !_pages.position.isScrollingNotifier.value) {
      _go(target);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
    } else {
      _animate(index);
    }
  }

  void _animate(int index) {
    _pages
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .ignore();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cardWidth =
          box.maxWidth * KVipRef.viewportFraction - KVipRef.cardGap;
      final cardHeight = cardWidth * KVipRef.cardHeight / KVipRef.cardWidth;
      final section = cardHeight + KVipRef.dividerMiddle + KVipRef.dividerEnd;
      return SizedBox(
        height: section,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BackdropPainter(cardHeight: cardHeight),
              ),
            ),
            SizedBox(
              height: cardHeight,
              child: PageView.builder(
                key: VipTierCarousel.carouselKey,
                controller: _pages,
                clipBehavior: Clip.none,
                onPageChanged: (i) => widget.onSelect(widget.tiers[i]),
                itemCount: widget.tiers.length,
                itemBuilder: (context, i) {
                  final tier = widget.tiers[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KVipRef.cardGap / 2,
                    ),
                    child: VipTierCard(
                      key: Key('vip.tab.${tier.code}'),
                      tier: tier,
                      caption: widget.captionOf(tier),
                      selected: tier.id == widget.selectedId,
                      owned: tier.id == widget.ownedId,
                      locked: widget.lockedIds.contains(tier.id),
                      onTap: () => _go(i),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// One tier card: a navy faceted card with a thin gold rim — the tier's
/// name in big gold italic letters at the top start, its badge at the top
/// end, one line at the bottom start.
class VipTierCard extends StatelessWidget {
  const new({
    required this.tier,
    required this.caption,
    required this.selected,
    required this.onTap,
    this.owned = false,
    this.locked = false,
    super.key,
  });

  final VipTier tier;
  final String caption;
  final bool selected;
  final bool owned;
  final bool locked;
  final VoidCallback onTap;

  /// The selected card's badge (the page's emblem).
  static const emblemKey = Key('vip.emblem');

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      selected: selected,
      label: tier.name,
      value: owned ? '${l10n.vipCurrent}، $caption' : caption,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: locked && !selected ? 0.55 : 1,
          child: LayoutBuilder(
            builder: (context, box) {
              // Everything scales with the card (300 pt wide at 393).
              final k = box.maxWidth / KVipRef.cardWidth;
              return CustomPaint(
                painter: const _CardPainter(),
                child: SizedBox.expand(
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        top: 3.9 * k,
                        end: 22.2 * k,
                        child: VipBadge(
                          key: selected ? emblemKey : null,
                          tier: tier,
                          size: 88 * k,
                          animate: selected,
                        ),
                      ),
                      PositionedDirectional(
                        top: 19.7 * k,
                        // The ink starts 20.9 pt in (the italic «V» has a
                        // wide bearing).
                        start: 14.9 * k,
                        end: 110 * k,
                        child: MediaQuery.withNoTextScaling(
                          child: _GoldName(
                            text: 'VIP ${tier.level}',
                            size: 40 * k,
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: 23.5 * k,
                        end: 16 * k,
                        // The baseline 16.6 pt over the card bottom (measured).
                        bottom: 20.4 * k,
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(
                              fontSize: 13 * k,
                              height: 1.2,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFFF8FCFF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The tier's name in heavy gold italic letters with a dark drop.
class _GoldName extends StatelessWidget {
  const new({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = context.textStyles.display.copyWith(
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: size * 0.04,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, size * 0.05),
            child: Text(
              text,
              maxLines: 1,
              style: style.copyWith(color: const Color(0xCC1A0E00)),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFDE8),
                Color(0xFFF8DC7C),
                Color(0xFFC9952F),
                Color(0xFFF3D27A),
              ],
              stops: [0, 0.42, 0.72, 1],
            ).createShader(rect),
            child: Text(
              text,
              maxLines: 1,
              style: style.copyWith(color: const Color(0xFFFFFFFF)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's navy facets, the big «V» of light lines and the gold rim.
class _CardPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(KVipRef.cardRadius * w / KVipRef.cardWidth),
    );
    canvas
      ..save()
      ..clipRRect(rrect)
      ..drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF232B4A), Color(0xFF161C36), Color(0xFF0F1430)],
          ).createShader(rect),
      );
    // Low-poly facets: a few lighter and darker triangles.
    void tri(List<Offset> p, Color c) => canvas.drawPath(
      Path()..addPolygon([for (final o in p) Offset(o.dx * w, o.dy * h)], true),
      Paint()..color = c,
    );
    tri(const [
      Offset.zero,
      Offset(0.32, 0),
      Offset(0.1, 0.55),
    ], const Color(0x142E3A66));
    tri(const [
      Offset(0.1, 0.55),
      Offset(0.32, 0),
      Offset(0.42, 0.62),
    ], const Color(0x1A3A4677));
    tri(const [
      Offset(0, 0.55),
      Offset(0.1, 0.55),
      Offset(0, 1),
    ], const Color(0x22000000));
    tri(const [
      Offset(0.1, 0.55),
      Offset(0.42, 0.62),
      Offset(0.3, 1),
    ], const Color(0x10FFFFFF));
    tri(const [
      Offset(0.42, 0.62),
      Offset(0.5, 0),
      Offset(0.7, 1),
    ], const Color(0x26000000));
    tri(const [
      Offset(0.3, 1),
      Offset(0.42, 0.62),
      Offset(0.7, 1),
    ], const Color(0x1A101633));
    // The «V»: a deep wedge between two light lines.
    final v = [
      Offset(0.66 * w, 0),
      Offset(1.0 * w, 0),
      Offset(0.81 * w, 0.78 * h),
    ];
    canvas.drawPath(
      Path()..addPolygon(v, true),
      Paint()..color = const Color(0x990A0E24),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x8C8A93B5);
    canvas
      ..drawLine(v[0], v[2], line)
      ..drawLine(v[1], v[2], line)
      ..drawLine(Offset(0.5 * w, 0), Offset(0.7 * w, h), line)
      ..drawLine(Offset(1.0 * w, 0.2 * h), Offset(0.87 * w, h), line)
      ..restore()
      // The rim: a thin gold line, pale at the corners.
      ..drawRRect(
        rrect.deflate(0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = const SweepGradient(
            colors: [
              Color(0xFFF6F0C8),
              Color(0xFFC9B27A),
              Color(0xFFEDEFF5),
              Color(0xFFB89A55),
              Color(0xFFF6F0C8),
            ],
          ).createShader(rect),
      );
  }

  @override
  bool shouldRepaint(_CardPainter old) => false;
}

/// Behind the cards (D304b, owner: «الخطين أسفل البطاقة اجعلها متطابقة
/// ١٠٠٪»), as measured on the reference (pt from the card top at 393 wide,
/// parabolas fitted to 9–14 points each, see the D304 report):
/// - the page is navy (#111121) above the upper arc;
/// - two thin gold arcs run from the screen edges behind the cards, rising
///   toward the edges — the upper one 107.75 at the middle → 30.7 at the
///   edges, the lower one 138.35 → 94.6 — brightest by the card (#8A8570,
///   #A29A7A) and fading to the edges (#4A4C3E);
/// - under each arc a lighter navy sheen (#282A3A → #191E2A over ≈ 27 pt)
///   on a deep plum (#191422), navy just over the divider's middle;
/// - the gold divider 25.5 under the card at the middle, 6.3 at the edges,
///   a 1 px cream core (#F3ECB3) fading to olive at the edges (#404037);
/// - the plum page (#1A1820) under the divider.
class _BackdropPainter extends CustomPainter {
  const new({required this.cardHeight});

  final double cardHeight;

  /// A parabola across the width: [edge] at both sides, [middle] at the
  /// centre (a quadratic Bézier is exactly that).
  static Path _parabola(double w, double edge, double middle) => Path()
    ..moveTo(0, edge)
    ..quadraticBezierTo(w / 2, 2 * middle - edge, w, edge);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final k = cardHeight / KVipRef.cardHeight;
    final upper = (edge: 30.7 * k, middle: 107.75 * k);
    final lower = (edge: 94.6 * k, middle: 138.35 * k);
    final divider = (
      edge: cardHeight + KVipRef.dividerEnd * k,
      middle: cardHeight + KVipRef.dividerMiddle * k,
    );
    // Between the upper arc and the divider: the dark plum-navy base.
    final base = _parabola(w, upper.edge, upper.middle)
      ..lineTo(w, divider.edge)
      ..quadraticBezierTo(
        w / 2,
        2 * divider.middle - divider.edge,
        0,
        divider.edge,
      )
      ..close();
    // The sheen under each arc, ≈ 27 pt deep — only beside the cards (the
    // reference shows none under their bottom edge).
    canvas
      ..drawPath(base, Paint()..color = const Color(0xFF191422))
      ..save()
      ..clipRect(Rect.fromLTRB(0, -cardHeight, w, cardHeight));
    for (final arc in [upper, lower]) {
      const steps = 14;
      for (var i = steps - 1; i >= 0; i--) {
        final dy = i * 2.0 * k;
        canvas.drawPath(
          _parabola(w, arc.edge + dy, arc.middle + dy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * k
            ..color = Color.lerp(
              const Color(0xFF282A3A),
              const Color(0xFF1A1E2A),
              i / (steps - 1),
            )!,
        );
      }
    }
    // Between the cards and the divider a deep plum (#191422), a navy
    // shadow just over the divider's middle (#0F1420); the plum page under
    // the divider (drawn far down: the page scrolls).
    canvas
      ..restore()
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, divider.middle - 6 * k),
          width: w * 0.5,
          height: 14 * k,
        ),
        Paint()
          ..color = const Color(0xFF0F1420)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * k),
      )
      ..drawPath(
        _parabola(w, divider.edge, divider.middle)
          ..lineTo(w, divider.edge + 4000)
          ..lineTo(0, divider.edge + 4000)
          ..close(),
        Paint()..color = KVipRef.page,
      );
    // The arcs.
    for (final (arc, near) in [
      (upper, const Color(0xFF8A8570)),
      (lower, const Color(0xFFA29A7A)),
    ]) {
      canvas.drawPath(
        _parabola(w, arc.edge, arc.middle),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 * k
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF4A4C3E),
              Color.lerp(const Color(0xFF4A4C3E), near, 0.55)!,
              near,
              near,
              Color.lerp(const Color(0xFF4A4C3E), near, 0.55)!,
              const Color(0xFF4A4C3E),
            ],
            stops: const [0, 0.05, 0.11, 0.89, 0.95, 1],
          ).createShader(Offset.zero & Size(w, cardHeight)),
      );
    }
    // The divider: a thin line, its cream core at the middle (no glow).
    const dividerColors = [
      Color(0xFF404037),
      Color(0xFF4E4E43),
      Color(0xFF706C50),
      Color(0xFFAE9A6C),
      Color(0xFFCFBC87),
      Color(0xFFDBCB91),
      Color(0xFFF3ECB3),
      Color(0xFFCABC86),
      Color(0xFFC9B480),
      Color(0xFFA6996B),
      Color(0xFF555343),
      Color(0xFF3F3E3A),
    ];
    const dividerStops = [
      0.0,
      0.027,
      0.082,
      0.163,
      0.272,
      0.38,
      0.5,
      0.652,
      0.761,
      0.87,
      0.951,
      1.0,
    ];
    final shader = const LinearGradient(
      colors: dividerColors,
      stops: dividerStops,
    ).createShader(Offset.zero & Size(w, size.height));
    final curve = _parabola(w, divider.edge, divider.middle);
    canvas
      // The reference's line sits in a thin dark warm edge (#181100).
      ..drawPath(
        curve,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * k
          ..shader = const LinearGradient(
            colors: [
              Color(0x00171200),
              Color(0xD9171200),
              Color(0xD9171200),
              Color(0x00171200),
            ],
            stops: [0.1, 0.3, 0.7, 0.9],
          ).createShader(Offset.zero & Size(w, size.height)),
      )
      ..drawPath(
        curve,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * k
          ..shader = shader,
      );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.cardHeight != cardHeight;
}

/// «⟡ امتيازات VIP ⟡» and the count line «(n/total)» under it.
class VipPrivilegesHeader extends StatelessWidget {
  const new({required this.count, required this.total, super.key});

  final int count;
  final int total;

  static const countKey = Key('vip.privileges.count');

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Column(
      children: [
        Semantics(
          container: true,
          header: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _Feather(),
              const SizedBox(width: 15),
              Flexible(
                child: Text(
                  context.l10n.vipPrivilegesHeader,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.title.copyWith(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: KVipRef.gold,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Transform.flip(flipX: true, child: const _Feather()),
            ],
          ),
        ),
        const SizedBox(height: KVipRef.countGap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              const Expanded(child: _FadeLine(towardEnd: true)),
              const SizedBox(width: 11),
              Text(
                '($count/$total)',
                key: countKey,
                textDirection: TextDirection.ltr,
                style: t.body.copyWith(
                  fontSize: 12.5,
                  height: 1.2,
                  color: KVipRef.countText,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(child: _FadeLine(towardEnd: false)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A thin line fading out toward the outside.
class _FadeLine extends StatelessWidget {
  const new({required this.towardEnd});

  /// Brightest at its end (the side of the count).
  final bool towardEnd;

  @override
  Widget build(BuildContext context) {
    final colors = [KVipRef.countLine.withValues(alpha: 0), KVipRef.countLine];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: towardEnd ? colors : colors.reversed.toList(),
        ),
      ),
    );
  }
}

/// The small gold ornament beside the header: a shaft with three pairs of
/// barbs, a dot at the end facing the text.
class _Feather extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(16, 10),
    painter: _FeatherPainter(Directionality.of(context)),
  );
}

class _FeatherPainter extends CustomPainter {
  const new(this.direction);

  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn pointing right (toward the text at the start side in LTR).
    if (direction == TextDirection.rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final h = size.height;
    final paint = Paint()
      ..color = const Color(0xFFE9C77B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h / 2), Offset(size.width - 3, h / 2), paint);
    for (var i = 0; i < 3; i++) {
      final x = 1.5 + i * 3.6;
      canvas
        ..drawLine(Offset(x, 1 + i * 0.6), Offset(x + 3.4, h / 2), paint)
        ..drawLine(Offset(x, h - 1 - i * 0.6), Offset(x + 3.4, h / 2), paint);
    }
    canvas.drawCircle(
      Offset(size.width - 1.6, h / 2),
      1.6,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_FeatherPainter old) => old.direction != direction;
}

/// The tier's perks, two a row: each a gold hexagon with its icon (or the
/// owner's art), the label under it (and its value when it has one).
class VipHexPerkGrid extends StatelessWidget {
  const new({required this.tier, required this.active, super.key});

  final VipTier tier;

  /// The caller holds this tier (or a higher one): nothing dimmed.
  final bool active;

  static const gridKey = Key('vip.perks');

  @override
  Widget build(BuildContext context) {
    // D374 (§10.166.5): what a holder has — its own and the inherited perks.
    final perks = tier.effectivePerks;
    return Column(
      key: gridKey,
      children: [
        for (var i = 0; i < perks.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: KVipRef.rowGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final perk in perks.skip(i).take(2))
                  Expanded(
                    child: _HexPerk(
                      key: Key('vip.perk.${perk.code}'),
                      perk: perk,
                      dimmed: !perk.available && !active,
                    ),
                  ),
                if (i + 1 >= perks.length) const Spacer(),
              ],
            ),
          ),
      ],
    );
  }
}

class _HexPerk extends StatelessWidget {
  const new({required this.perk, required this.dimmed, super.key});

  final VipPerk perk;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final l10n = context.l10n;
    final amount = perk.number;
    final value = !perk.available
        // D374: a perk not built yet says «قريباً» (never shown as active).
        ? l10n.vipPerkSoonTag
        : switch ((perk.code, amount)) {
            ('DAILY_BULLET', final n?) => l10n.vipPerkPerDay('$n'),
            ('LEVEL_SPEEDUP', final n?) => '+$n%',
            _ => null,
          };
    final hasArt = perk.still != null || perk.animation != null;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
        child: Column(
          children: [
            Semantics(
              image: true,
              label: perk.title,
              child: CustomPaint(
                painter: const _HexPainter(),
                child: SizedBox(
                  width: KVipRef.hexWidth,
                  height: KVipRef.hexHeight,
                  child: Center(
                    child: hasArt
                        ? SizedBox.square(
                            dimension: 30,
                            child: VipAnimatedArt(
                              animation: perk.animation,
                              still: perk.still,
                            ),
                          )
                        : ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFF4C2), Color(0xFFE9B949)],
                            ).createShader(rect),
                            child: Icon(
                              VipPrivilegeCard.iconOf(perk.code),
                              size: 28,
                              color: const Color(0xFFFFFFFF),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KVipRef.labelGap),
            Text(
              perk.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(
                fontSize: 13.5,
                height: 1.2,
                fontWeight: FontWeight.w400,
                color: KVipRef.gold,
              ),
            ),
            if (value != null)
              Text(
                value,
                maxLines: 1,
                textDirection: value.startsWith('+') ? TextDirection.ltr : null,
                style: t.caption.copyWith(
                  fontSize: 12,
                  height: 1.3,
                  color: KVipRef.countText.withValues(alpha: 0.75),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A pointy-top hexagon: a dark glossy fill with a thin gold rim.
class _HexPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hex = Path()
      ..addPolygon([
        Offset(w / 2, 0),
        Offset(w, h / 4),
        Offset(w, h * 3 / 4),
        Offset(w / 2, h),
        Offset(0, h * 3 / 4),
        Offset(0, h / 4),
      ], true);
    final rect = Offset.zero & size;
    canvas
      ..drawPath(
        hex,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3B3B42), Color(0xFF232228), Color(0xFF141418)],
          ).createShader(rect),
      )
      ..drawPath(
        hex,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8D2), KVipRef.goldLine, Color(0xFFB8893A)],
          ).createShader(rect),
      );
  }

  @override
  bool shouldRepaint(_HexPainter old) => false;
}
