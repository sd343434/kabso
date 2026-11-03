import 'dart:async';
import 'dart:io' show HttpClient;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The parts of the «شراء VIP» page (D252b v2, owner «طبق هذا التصميم ١٠٠٪»,
/// reference `REFERENCE_vip_design_v2`): a horizontal tier tab row (VIP1…VIPn,
/// the selected one gold with an underline), the selected tier's large centred
/// BADGE, a gold crown divider ornament, category section headers with a count,
/// and a 3-column perks grid (each cell a thumbnail, a title and a one-line
/// subtitle), in Kabso's dark purple + gold identity, RTL-correct.
///
/// ART: the owner's reference uses third-party ornate art (an eagle/lion crest,
/// gold frames and a winged crown) that Kabso must not copy. The badge and the
/// perk thumbnails are **slots** for the owner's own art (hosted SVGA + still,
/// uploaded from the admin panel); until a tier has art a tier-coloured
/// placeholder shows. The crown divider is drawn in code (a gold crown + wings),
/// not the reference's artwork.

/// The page's dark background (a deep purple-black, so the gold reads).
const Color vipBackground = Color(0xFF0E0A16);
const Color vipGold = Color(0xFFF5C451);
const Color vipGoldBright = Color(0xFFFFE7A3);
const Color vipGoldDeep = Color(0xFFB7811A);

/// A muted lilac for secondary text.
const Color vipMuted = Color(0xFF9A8CB0);

/// The text on a tier colour: dark on light tiers, white on dark ones.
Color vipOnColor(Color c) =>
    c.computeLuminance() > 0.45 ? const Color(0xFF1A1420) : Colors.white;

/// A tier colour lightened by [t] toward white.
Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;

/// A tier colour darkened by [t] toward black.
Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

// ---- Owner art: SVGA (looping) with a still fallback ------------------------

/// Builds the still image for [src] (a hosted https URL), or null. Nothing is
/// bundled: every VIP art is uploaded from the admin panel.
Widget? _stillOf(String? src, BoxFit fit) {
  if (src == null) return null;
  Widget onError(BuildContext _, Object _, StackTrace? _) =>
      const SizedBox.shrink();
  return Image.network(src, fit: fit, errorBuilder: onError);
}

/// The owner's VIP art: a looping SVGA ([animation]) over its [still], both
/// hosted (https) and uploaded from the admin panel (the gifts `animationUrl`
/// pattern, D126) — nothing is bundled, so the app binary stays light. The live
/// app fetches and decodes the SVGA and loops it; the still shows until it
/// decodes. In widget tests and the screenshot harness ([animate] off, or
/// [animationsEnabled] off) only the still is drawn, so nothing animates
/// asynchronously (the SVGA decode runs outside fake time and an endless loop
/// never settles).
class VipAnimatedArt extends StatefulWidget {
  const new({
    required this.animation,
    required this.still,
    super.key,
    this.fit = BoxFit.contain,
    this.animate = true,
    this.placeholder,
  });

  final String? animation;
  final String? still;
  final BoxFit fit;
  final bool animate;
  final Widget? placeholder;

  /// Widget tests and the screenshot harness set this false so only the still
  /// paints (set by `test/flutter_test_config.dart`).
  static bool animationsEnabled = true;

  bool get _canPlay =>
      animate &&
      animationsEnabled &&
      animation != null &&
      animation!.startsWith('http');

  @override
  State<VipAnimatedArt> createState() => _VipAnimatedArtState();
}

class _VipAnimatedArtState extends State<VipAnimatedArt>
    with SingleTickerProviderStateMixin {
  static final Map<String, MovieEntity> _cache = {};

  SVGAAnimationController? _controller;
  bool _ready = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget._canPlay) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) return; // reduced motion.
    unawaited(_load(widget.animation!));
  }

  static Future<Uint8List?> _fetch(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final chunks = await response.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      return Uint8List.fromList(chunks);
    } finally {
      client.close();
    }
  }

  Future<void> _load(String url) async {
    try {
      var movie = _cache[url];
      if (movie == null) {
        final bytes = await _fetch(url);
        if (bytes == null || !mounted) return;
        movie = await SVGAParser.shared.decodeFromBuffer(bytes);
        _cache[url] = movie..autorelease = false;
      }
      if (!mounted) return;
      final controller = SVGAAnimationController(vsync: this)
        ..muted = true
        ..videoItem = movie
        ..repeat();
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } on Object catch (e) {
      // A broken file keeps the still.
      debugPrint('VipAnimatedArt($url): $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_ready && controller != null) {
      return SVGAImage(
        controller,
        fit: widget.fit,
        clearsAfterStop: false,
        filterQuality: FilterQuality.medium,
      );
    }
    return _stillOf(widget.still, widget.fit) ??
        widget.placeholder ??
        const SizedBox.shrink();
  }
}

/// The tier BADGE (central crest): the owner's badge art (SVGA + still), or a
/// token placeholder (a gold-ringed medal in the tier's colour) when the tier
/// has no art yet. This is the slot the owner's crest art fills — it does not
/// copy the reference's third-party crest.
class VipBadge extends StatelessWidget {
  const new({
    required this.tier,
    required this.size,
    super.key,
    this.animate = true,
  });

  final VipTier tier;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final color = Color(tier.color);
    if (tier.badgeStill != null || tier.badgeAnimation != null) {
      return SizedBox(
        width: size,
        height: size,
        child: VipAnimatedArt(
          animation: tier.badgeAnimation,
          still: tier.badgeStill,
          animate: animate,
        ),
      );
    }
    // Placeholder medal (a tier with no art yet).
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [vipGold, vipGoldBright, vipGoldDeep, vipGold],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 22),
        ],
      ),
      padding: EdgeInsets.all(size * 0.06),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_lighten(color, 0.35), color, _darken(color, 0.3)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.emoji_events_rounded,
            size: size * 0.5,
            color: vipGoldBright,
          ),
        ),
      ),
    );
  }
}

/// The small gold name plate under a placeholder badge (the reference's
/// «VIP 5» plate; the owner's badge art carries its own).
class VipNamePlate extends StatelessWidget {
  const new({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.pill),
      gradient: const LinearGradient(
        colors: [vipGoldDeep, vipGold, vipGoldBright, vipGold, vipGoldDeep],
      ),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
    ),
    child: Text(
      name,
      style: context.textStyles.caption.copyWith(
        color: const Color(0xFF3A2A08),
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    ),
  );
}

// ---- The horizontal tier tab row --------------------------------------------

/// The tier tabs (VIP1 … VIPn across the width): the selected tier in gold with
/// a short gold underline, the others muted; a tap selects. The caller's held
/// tier carries a small check. Mirrored in RTL.
class VipTierTabs extends StatelessWidget {
  const new({
    required this.tiers,
    required this.selectedId,
    required this.heldId,
    required this.onSelect,
    super.key,
  });

  final List<VipTier> tiers;
  final String selectedId;
  final String? heldId;
  final void Function(VipTier) onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final tier in tiers)
        Expanded(
          child: _Tab(
            tier: tier,
            selected: tier.id == selectedId,
            held: tier.id == heldId,
            onTap: () => onSelect(tier),
          ),
        ),
    ],
  );
}

class _Tab extends StatelessWidget {
  const new({
    required this.tier,
    required this.selected,
    required this.held,
    required this.onTap,
  });

  final VipTier tier;
  final bool selected;
  final bool held;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return Semantics(
      key: Key('vip.tab.${tier.code}'),
      button: true,
      selected: selected,
      label: [tier.name, if (held) l10n.vipCurrent].join('، '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (held) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: vipGold,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      tier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: t.bodyStrong.copyWith(
                        color: selected ? vipGoldBright : vipMuted,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The underline indicator under the selected tier.
            Container(
              height: 3,
              width: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KRadius.pill),
                gradient: selected
                    ? const LinearGradient(colors: [vipGold, vipGoldBright])
                    : null,
                color: selected ? null : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- The crown divider ornament ---------------------------------------------

/// The gold crown + wings divider under the badge (the reference's winged
/// crown, drawn in code — a gold crown medallion flanked by feathered wings).
/// Decorative: it carries no state.
class VipCrownDivider extends StatelessWidget {
  const new({super.key, this.height = 46});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: const _WingPainter(toEnd: false),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
          child: CustomPaint(
            size: Size(height * 0.86, height),
            painter: const _CrownPainter(),
          ),
        ),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: const _WingPainter(toEnd: true),
          ),
        ),
      ],
    ),
  );
}

/// One feathered gold wing sweeping out from the centre.
class _WingPainter extends CustomPainter {
  const new({required this.toEnd});

  /// The wing on the trailing side (mirrored horizontally).
  final bool toEnd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Draw as if sweeping to the right; mirror for the leading-side wing.
    if (!toEnd) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final mid = size.height / 2;
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [vipGoldBright, vipGold, vipGoldDeep],
      ).createShader(Offset.zero & size);
    // The spine.
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      gold..strokeWidth = 2.4,
    );
    // Feathers fanning up and down, shorter toward the far end.
    final n = (size.width / 10).clamp(4, 9).toInt();
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1);
      final x = t * size.width;
      final len = (1 - t) * size.height * 0.42 + 3;
      final lift = math.sin(math.pi * t) * 3;
      gold.strokeWidth = 1.6;
      final inner = x - len * 0.3;
      canvas
        ..drawLine(Offset(x, mid - lift), Offset(inner, mid - len), gold)
        ..drawLine(Offset(x, mid + lift), Offset(inner, mid + len), gold);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WingPainter oldDelegate) => false;
}

/// A small gold crown with a red gem (the centre of the divider).
class _CrownPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseTop = h * 0.66;
    final crown = Path()
      ..moveTo(w * 0.08, baseTop)
      ..lineTo(w * 0.08, h * 0.42)
      ..lineTo(w * 0.28, h * 0.6)
      ..lineTo(w * 0.5, h * 0.24)
      ..lineTo(w * 0.72, h * 0.6)
      ..lineTo(w * 0.92, h * 0.42)
      ..lineTo(w * 0.92, baseTop)
      ..close();
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [vipGoldBright, vipGold, vipGoldDeep],
      ).createShader(Offset.zero & size);
    canvas
      ..drawPath(crown, fill)
      // The base band.
      ..drawRect(
        Rect.fromLTRB(w * 0.08, baseTop, w * 0.92, h * 0.9),
        fill,
      )
      // The centre gem.
      ..drawCircle(
        Offset(w * 0.5, h * 0.78),
        w * 0.09,
        Paint()..color = const Color(0xFFD23B3B),
      );
    // The spike tips.
    final tip = Paint()..color = vipGoldBright;
    for (final x in [0.08, 0.5, 0.92]) {
      canvas.drawCircle(Offset(w * x, h * (x == 0.5 ? 0.22 : 0.4)), 2, tip);
    }
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => false;
}

// ---- The perks section ------------------------------------------------------

/// A category section header: small crown flourishes on each side, the category
/// title and, when the category has perks, a «(granted/total)» count under it
/// (the reference's «Identification (6/6)»).
class VipSectionHeader extends StatelessWidget {
  const new({required this.title, super.key, this.count});

  final String title;

  /// `(granted, total)`; null hides the count line.
  final (int, int)? count;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final count = this.count;
    return Row(
      children: [
        const Expanded(child: _Flourish(toEnd: false)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.bodyStrong.copyWith(
                  color: const Color(0xFFF2ECF8),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (count != null)
                Text(
                  '(${count.$1}/${count.$2})',
                  style: t.caption.copyWith(color: vipMuted),
                ),
            ],
          ),
        ),
        const Expanded(child: _Flourish(toEnd: true)),
      ],
    );
  }
}

/// A small gold flourish (a thin fading bar with a diamond finial) beside a
/// section title.
class _Flourish extends StatelessWidget {
  const new({required this.toEnd});

  final bool toEnd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (toEnd) _diamond(),
      Expanded(
        child: Container(
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: toEnd ? Alignment.centerLeft : Alignment.centerRight,
              end: toEnd ? Alignment.centerRight : Alignment.centerLeft,
              colors: [vipGold, vipGold.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
      if (!toEnd) _diamond(),
    ],
  );

  Widget _diamond() => Transform.rotate(
    angle: math.pi / 4,
    child: Container(width: 5, height: 5, color: vipGold),
  );
}

/// One perk cell (the reference's grid cell): the perk's art thumbnail on top,
/// a bold title and a one-line grey subtitle; a small lock marks a perk whose
/// feature is not built yet («قريباً»). The art fills the slot the owner's
/// uploaded art (still thumbnail) provides; a tier-coloured icon shows until
/// then.
class VipPerkCard extends StatelessWidget {
  const new({
    required this.perk,
    required this.tier,
    required this.active,
    required this.width,
    super.key,
  });

  final VipPerk perk;
  final VipTier tier;

  /// The caller holds this tier (or a higher one) now.
  final bool active;
  final double width;

  static const Color _title = Color(0xFFE7C77E);

  static IconData iconFor(String code) => switch (code) {
    'BADGE' => Icons.verified_rounded,
    'AVATAR_FRAME' => Icons.filter_frames_rounded,
    'PROFILE_CARD' => Icons.badge_rounded,
    'CHAT_BUBBLE' => Icons.chat_bubble_rounded,
    'CHAT_NAME_COLOR' => Icons.format_color_text_rounded,
    'ENTRY_BANNER' => Icons.flag_rounded,
    'ENTRY_EFFECT' => Icons.auto_awesome_rounded,
    'MIC_SOUND_WAVE' => Icons.graphic_eq_rounded,
    'DAILY_BULLET' => Icons.campaign_rounded,
    'VIEWER_LIST_PRIORITY' => Icons.format_list_numbered_rounded,
    'MONTHLY_GIFT' => Icons.redeem_rounded,
    _ => Icons.workspace_premium_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final color = Color(tier.color);
    final on = perk.available && active;
    final state = !perk.available
        ? l10n.liveSoon
        : on
        ? l10n.vipPerkActive
        : l10n.vipPerkWith(tier.name);
    final subtitle = perk.description ?? state;
    return SizedBox(
      width: width,
      child: Semantics(
        key: Key('vip.perk.${perk.code}'),
        label: [perk.title, ?perk.description, state].join('، '),
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.08,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: perk.still != null
                        ? VipAnimatedArt(
                            animation: null,
                            still: perk.still,
                            animate: false,
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(KRadius.md),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _darken(color, 0.3).withValues(alpha: 0.8),
                                  const Color(0xFF17121F),
                                ],
                              ),
                              border: Border.all(
                                color: vipGold.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                iconFor(perk.code),
                                size: width * 0.34,
                                color: perk.available
                                    ? vipGoldBright
                                    : const Color(0xFF6E6480),
                              ),
                            ),
                          ),
                  ),
                  if (!perk.available)
                    const PositionedDirectional(
                      end: 4,
                      top: 4,
                      child: Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Color(0xFFCDBFE0),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              perk.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodyStrong.copyWith(
                color: _title,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: vipMuted),
            ),
          ],
        ),
      ),
    );
  }
}
