import 'dart:async';
import 'dart:io' show HttpClient;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The parts of the «شراء VIP» page (D252b, owner «طبق هذا التصميم ١٠٠٪»):
/// the hanging crest banner, the curved tier track, the upgrade bar and the
/// crown-topped perks grid, in Kabso's dark purple + gold identity.
///
/// ART: the owner's reference uses a third-party ornate eagle crest and gold
/// frames that Kabso must not copy. The emblem and the perk thumbnails are
/// **placeholder slots** sized and placed per the reference — a tier-coloured
/// banner with a generic medal and the tier name. When the owner uploads the
/// badge and perk art (hosted SVGA + still, admin panel) they fill the slots;
/// until then a token placeholder shows.

/// The page's dark background (a deep purple-black, so the gold reads).
const Color vipBackground = Color(0xFF0E0A16);
const Color vipGold = Color(0xFFF5C451);
const Color vipGoldBright = Color(0xFFFFE7A3);
const Color vipGoldDeep = Color(0xFFB7811A);

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
/// copy the reference's eagle crest.
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

// ---- The hanging banner -----------------------------------------------------

/// A banner clipped to a swallowtail bottom (a classic hanging flag).
class _SwallowtailClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) {
    final notch = size.height * 0.12;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - notch)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// One hanging banner in [color]: a swallowtail flag with a top peg, an
/// optional emblem and a label. The faded side banners pass [dim].
class VipHangingBanner extends StatelessWidget {
  const new({
    required this.color,
    required this.width,
    required this.height,
    required this.label,
    super.key,
    this.emblem,
    this.dim = false,
    this.labelKey,
    this.showLabel = true,
  });

  final Color color;
  final double width;
  final double height;
  final String label;
  final Widget? emblem;
  final bool dim;
  final Key? labelKey;

  /// When false the banner shows no name (the badge art carries its own plate).
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final onColor = vipOnColor(color);
    final banner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The peg ring that hangs the banner from the rail.
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: vipGold, width: 2),
            color: vipBackground,
          ),
        ),
        SizedBox(
          width: width,
          height: height,
          child: ClipPath(
            clipper: const _SwallowtailClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_lighten(color, 0.22), color, _darken(color, 0.28)],
                ),
                border: Border.all(color: vipGold.withValues(alpha: 0.7)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.08,
                  vertical: height * 0.08,
                ),
                child: Column(
                  mainAxisAlignment: showLabel
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.center,
                  children: [
                    if (emblem == null)
                      const Spacer()
                    else if (showLabel)
                      emblem!
                    else
                      Expanded(child: emblem!),
                    if (showLabel)
                      Padding(
                        padding: EdgeInsets.only(bottom: height * 0.08),
                        child: Text(
                          label,
                          key: labelKey,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.title.copyWith(
                            color: onColor,
                            fontWeight: FontWeight.w900,
                            fontSize: width * 0.2,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: _darken(color, 0.5),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return dim ? Opacity(opacity: 0.45, child: banner) : banner;
  }
}

/// The top rail the banners hang from: a thin gold gradient bar with finials.
class VipRail extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _finial(),
      Expanded(
        child: Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                vipGoldDeep,
                vipGold,
                vipGoldBright,
                vipGold,
                vipGoldDeep,
              ],
            ),
          ),
        ),
      ),
      _finial(),
    ],
  );

  Widget _finial() => Transform.rotate(
    angle: math.pi / 4,
    child: Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: vipGold,
        border: Border.all(color: vipGoldBright),
      ),
    ),
  );
}

// ---- The curved tier track --------------------------------------------------

/// Where node [i] of [n] sits in a unit box: x left→right, y on a smile arc
/// (the ends high, the middle low), matching the reference.
({double x, double y}) vipArcPoint(int i, int n) {
  final t = n <= 1 ? 0.5 : i / (n - 1);
  return (x: t, y: math.sin(math.pi * t));
}

/// Paints the gold arc line the nodes sit on (symmetric, so it needs no
/// mirroring in RTL).
class _ArcPainter extends CustomPainter {
  const new({required this.margin, required this.dip, required this.top});

  final double margin;
  final double dip;
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final usable = size.width - 2 * margin;
    for (var s = 0; s <= 48; s++) {
      final t = s / 48;
      final x = margin + t * usable;
      final y = top + dip * math.sin(math.pi * t);
      if (s == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [vipGoldDeep, vipGold, vipGoldBright, vipGold, vipGoldDeep],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => false;
}

/// The curved tier track: the tiers as nodes along a gold smile arc, the
/// selected one raised and enlarged, each node tappable to select its tier.
/// Mirrored in RTL. (With many tiers the labels sit close; the owner adds a
/// handful.)
class VipTierArc extends StatelessWidget {
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

  static const double _height = 118;
  static const double _margin = 34;
  static const double _dip = 54;
  static const double _top = 26;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final usable = width - 2 * _margin;
          final nodes = <Widget>[];
          for (var i = 0; i < tiers.length; i++) {
            final tier = tiers[i];
            final p = vipArcPoint(i, tiers.length);
            final cx = _margin + p.x * usable;
            final cy = _top + _dip * p.y;
            final drawX = rtl ? width - cx : cx;
            final selected = tier.id == selectedId;
            final r = selected ? 15.0 : 10.0;
            nodes.add(
              Positioned(
                left: drawX - 44,
                top: cy - 22,
                width: 88,
                height: 66,
                child: _ArcNode(
                  tier: tier,
                  radius: r,
                  selected: selected,
                  held: tier.id == heldId,
                  onTap: () => onSelect(tier),
                ),
              ),
            );
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: CustomPaint(
                  painter: _ArcPainter(
                    margin: VipTierArc._margin,
                    dip: VipTierArc._dip,
                    top: VipTierArc._top,
                  ),
                ),
              ),
              ...nodes,
            ],
          );
        },
      ),
    );
  }
}

class _ArcNode extends StatelessWidget {
  const new({
    required this.tier,
    required this.radius,
    required this.selected,
    required this.held,
    required this.onTap,
  });

  final VipTier tier;
  final double radius;
  final bool selected;
  final bool held;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = Color(tier.color);
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
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? LinearGradient(colors: [vipGoldBright, color])
                    : null,
                color: selected ? null : vipBackground,
                border: Border.all(
                  color: selected
                      ? vipGoldBright
                      : vipGold.withValues(alpha: 0.8),
                  width: selected ? 2 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: held
                  ? Icon(
                      Icons.check_rounded,
                      size: radius,
                      color: vipOnColor(color),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              tier.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                color: selected
                    ? vipGoldBright
                    : vipGold.withValues(alpha: 0.75),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                fontSize: selected ? 12 : 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- The upgrade bar --------------------------------------------------------

/// The upgrade progress bar (the reference's «Upgrade: …» bar): a gold label
/// at the reading end, a track filled to the caller's rank with a knob, and a
/// balance line under it. For bought VIP the fill is the held tier's rank on
/// the ladder (0 when not a member) — it is a status indicator, not a drag.
class VipUpgradeBar extends StatelessWidget {
  const new({
    required this.upgradeLabel,
    required this.fill,
    required this.balanceCoins,
    super.key,
  });

  final String upgradeLabel;
  final double fill;
  final int? balanceCoins;

  static const barKey = Key('vip.progress');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return Column(
      key: barKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            upgradeLabel,
            style: t.caption.copyWith(
              color: vipGoldBright,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: KSpacing.xs),
        LayoutBuilder(
          builder: (context, c) {
            final clamped = fill.clamp(0.0, 1.0);
            return SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Align(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2233),
                          borderRadius: BorderRadius.circular(KRadius.pill),
                          border: Border.all(
                            color: vipGoldDeep.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      child: FractionallySizedBox(
                        widthFactor: clamped,
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [vipGoldDeep, vipGold, vipGoldBright],
                            ),
                            borderRadius: BorderRadius.circular(KRadius.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: (c.maxWidth - 16) * clamped,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [vipGoldBright, vipGold],
                        ),
                        boxShadow: [
                          BoxShadow(color: Color(0x66F5C451), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: KSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.vipBalanceLabel}: ',
                style: t.caption.copyWith(color: const Color(0xFFB9A9C9)),
              ),
              if (balanceCoins != null)
                CoinAmount(
                  balanceCoins!,
                  size: 13,
                  style: t.caption.copyWith(
                    color: vipGoldBright,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  '…',
                  style: t.caption.copyWith(color: const Color(0xFFB9A9C9)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- The perks section ------------------------------------------------------

/// The crown header strip over the perks (a gold placeholder ornament, not the
/// reference's third-party crown) with the section title.
class VipCrownHeader extends StatelessWidget {
  const new({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _bar(toEnd: false)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: vipGold,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyStrong.copyWith(
                color: vipGoldBright,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      Expanded(child: _bar(toEnd: true)),
    ],
  );

  Widget _bar({required bool toEnd}) => Container(
    height: 2,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: toEnd ? Alignment.centerLeft : Alignment.centerRight,
        end: toEnd ? Alignment.centerRight : Alignment.centerLeft,
        colors: [vipGold, vipGold.withValues(alpha: 0)],
      ),
    ),
  );
}

/// One perk card: a tier-coloured thumbnail slot (a placeholder for the
/// owner's art) with a lock + «قريباً» while the perk is not built, and the
/// perk's title under it.
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

  static IconData iconFor(String code) => switch (code) {
    'BADGE' => Icons.verified_rounded,
    'AVATAR_FRAME' => Icons.filter_frames_rounded,
    'CHAT_NAME_COLOR' => Icons.format_color_text_rounded,
    'ENTRY_BANNER' => Icons.flag_rounded,
    'ENTRY_EFFECT' => Icons.auto_awesome_rounded,
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
              aspectRatio: 1.35,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.md),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _darken(color, 0.35).withValues(alpha: 0.9),
                      const Color(0xFF17121F),
                    ],
                  ),
                  border: Border.all(
                    color: on
                        ? vipGold.withValues(alpha: 0.8)
                        : vipGold.withValues(alpha: 0.25),
                  ),
                ),
                child: Stack(
                  children: [
                    // The perk's own art (still thumbnail in the grid), or a
                    // generic icon when the perk has no art yet.
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
                        child: perk.still != null
                            ? VipAnimatedArt(
                                animation: null,
                                still: perk.still,
                                animate: false,
                              )
                            : Center(
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
                        end: 6,
                        top: 6,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Color(0xFFB9A9C9),
                        ),
                      ),
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: on ? color : const Color(0xCC17121F),
                          borderRadius: const BorderRadiusDirectional.only(
                            bottomStart: Radius.circular(KRadius.md),
                            bottomEnd: Radius.circular(KRadius.md),
                          ),
                        ),
                        child: Text(
                          state,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: on
                                ? vipOnColor(color)
                                : const Color(0xFFB9A9C9),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              perk.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: const Color(0xFFE8DDF5)),
            ),
          ],
        ),
      ),
    );
  }
}
