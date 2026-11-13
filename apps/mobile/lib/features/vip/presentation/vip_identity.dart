import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// v1.131-social (D378, owner 2026-11-11, CONVENTIONS §10.168): the VIP
// identity perks as the app draws them — the animated cover, the golden ID
// chip, the signature under posts and public messages, the badge on posts,
// the story ring, the glowing live-chat name and the DM bubble. Each shows
// only for a member whose look (their tier and every lower one, D258's
// inheritance) holds the perk; nothing changes for anyone else.

/// Whether motion may play here: the platform's reduce-motion setting and
/// the test harness switch ([VipAnimatedArt.animationsEnabled]).
bool vipMotionAllowed(BuildContext context) =>
    VipAnimatedArt.animationsEnabled &&
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

// ---- ANIMATED_COVER ---------------------------------------------------------

/// D378 (§10.168.1, ANIMATED_COVER): the tier's cover art (SVGA / MP4 /
/// still, 1080 × 720) across the profile's cover while the member holds the
/// perk. Owner's rule kept here: the tier's art plays OVER the person's own
/// cover (which stays saved and comes back when the VIP ends); a cover the
/// person changes while a member is saved as usual. Without the perk or its
/// art: nothing (the own cover shows).
class VipAnimatedCover extends ConsumerWidget {
  const new({required this.vip, super.key});

  final UserVip? vip;

  static const coverKey = Key('vip.animatedCover');

  /// The perk's art, or null (not held, or no art uploaded).
  static VipPerk? perkOf(VipLook? look) {
    if (look == null || !look.vip.member) return null;
    final perk = look.perk(VipPerks.animatedCover);
    if (perk == null || (perk.still == null && perk.animation == null)) {
      return null;
    }
    return perk;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perk = perkOf(ref.watch(vipLookProvider(vip)));
    if (perk == null) return const SizedBox.shrink();
    return IgnorePointer(
      key: coverKey,
      child: VipAnimatedArt(
        animation: perk.animation,
        still: perk.still,
        video: perk.video,
        fit: BoxFit.cover,
        animate: vipMotionAllowed(context),
      ),
    );
  }
}

// ---- GOLDEN_ID --------------------------------------------------------------

/// D378 (§10.168.4, GOLDEN_ID): the golden ID «آيدي ذهبي» as the gold
/// special-ID pill the staff IDs wear (D299h, [KStaffIdText]) — «ID 8888»,
/// always left to right. Null [goldenId]: nothing.
class VipGoldenIdChip extends StatelessWidget {
  const new({
    required this.goldenId,
    super.key,
    this.height = KStaffIdText.normal,
    this.effects = KSpecialIdEffects.sweepOnly,
  });

  final UserGoldenId? goldenId;
  final double height;
  final KSpecialIdEffects effects;

  static const chipKey = Key('vip.goldenId');

  /// The text on the pill.
  static String label(UserGoldenId id) => 'ID ${id.number}';

  @override
  Widget build(BuildContext context) {
    final id = goldenId;
    if (id == null) return const SizedBox.shrink();
    // D388: a tap says what the golden ID is.
    return KBadgeExplainer(
      message: context.l10n.badgeExplainGoldenId(id.number),
      child: KStaffIdText(
        label(id),
        key: chipKey,
        height: height,
        semanticHint: context.l10n.vipGoldenIdHint,
        effects: effects,
      ),
    );
  }
}

// ---- ANIMATED_SIGNATURE -----------------------------------------------------

/// Geometry of the signature line.
abstract final class KVipSignature {
  static const double height = 26;
  static const double fontSize = 13;
  static const double radius = 13;
  static const double paddingH = 12;

  /// The light that sweeps across the text, once every [period].
  static const Duration period = Duration(milliseconds: 2600);
}

/// D378 (§10.168.5, ANIMATED_SIGNATURE): the member's signature under their
/// posts and public bullet messages — on the perk's art (750 × 200, its SVGA
/// playing) or, without art, on a pill in deep shades of the tier's colour,
/// the text in the tier's light tint with a light sweeping across it.
/// Reduce motion (and the tests): still. Not held, or no text: nothing.
class VipSignatureLine extends ConsumerStatefulWidget {
  const new({required this.vip, super.key, this.maxWidth = 260});

  final UserVip? vip;
  final double maxWidth;

  static const signatureKey = Key('vip.signature');

  @override
  ConsumerState<VipSignatureLine> createState() => _VipSignatureLineState();
}

class _VipSignatureLineState extends ConsumerState<VipSignatureLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: KVipSignature.period,
  );

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ref.watch(vipLookProvider(widget.vip));
    final text = look?.signature;
    if (look == null || text == null) {
      if (_sweep.isAnimating) _sweep.stop();
      return const SizedBox.shrink();
    }
    final motion = vipMotionAllowed(context);
    if (motion && !_sweep.isAnimating) {
      _sweep.repeat();
    } else if (!motion && _sweep.isAnimating) {
      _sweep.stop();
    }
    final perk = look.perk(VipPerks.signature);
    final art = perk != null && (perk.still != null || perk.animation != null);
    final (top, bottom) = look.bubbleShades;
    final ink = vipNameTint(look.color);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final label = Text(
      // A mixed-direction signature keeps its order.
      KFormat.bidiIsolate(text),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textScaler: scaler,
      style: context.textStyles.caption.copyWith(
        fontSize: KVipSignature.fontSize,
        height: 1.1,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: ink,
        shadows: const [Shadow(color: Color(0x99000000), blurRadius: 2)],
      ),
    );
    final swept = motion
        ? AnimatedBuilder(
            animation: _sweep,
            child: label,
            builder: (context, child) => ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) {
                final x = -0.5 + 2 * _sweep.value;
                return LinearGradient(
                  colors: [
                    ink.withValues(alpha: 0),
                    const Color(0xCCFFFFFF),
                    ink.withValues(alpha: 0),
                  ],
                  stops: [
                    (x - 0.15).clamp(0, 1),
                    x.clamp(0, 1),
                    (x + 0.15).clamp(0, 1),
                  ],
                ).createShader(rect);
              },
              child: child,
            ),
          )
        : label;
    return Semantics(
      label: context.l10n.vipSignatureSemantics(text),
      excludeSemantics: true,
      child: ConstrainedBox(
        key: VipSignatureLine.signatureKey,
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth,
          minHeight: KVipSignature.height,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KVipSignature.radius),
            gradient: art ? null : LinearGradient(colors: [top, bottom]),
            color: art ? const Color(0xFF1A1020) : null,
            border: Border.all(color: const Color(0xB3FFE08A), width: 0.8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KVipSignature.radius),
            child: Stack(
              children: [
                if (art)
                  Positioned.fill(
                    child: ColorFiltered(
                      // Darkened, so the light tint reads on any art.
                      colorFilter: const ColorFilter.mode(
                        Color(0x80000000),
                        BlendMode.srcATop,
                      ),
                      child: VipAnimatedArt(
                        animation: perk.animation,
                        still: perk.still,
                        fit: BoxFit.fill,
                        animate: motion,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KVipSignature.paddingH,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.draw_rounded, size: 13, color: ink),
                      const SizedBox(width: 5),
                      Flexible(child: swept),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- STORY_RING -------------------------------------------------------------

/// D378 (§10.168.7, STORY_RING): the ring's colours along its sweep — the
/// perk's colour (or the tier's), a light tint of it and back — or null
/// without the perk. The reusable hook for any story ring (the tray, the
/// viewer, and the people carousel's `StoryRingStyle` on its branch:
/// `StoryRingStyle(colors: vipStoryRingColors(look)!)`).
List<Color>? vipStoryRingColors(VipLook? look) {
  final c = look?.storyRingColor;
  if (c == null) return null;
  final light = Color.lerp(c, const Color(0xFFFFFFFF), 0.55)!;
  return [c, light, const Color(0xFFFFE08A), c];
}

/// Paints a VIP story ring: a sweep of [colors] [stroke] wide inside the
/// box, dimmed to [opacity] (a seen story).
class VipStoryRingPainter extends CustomPainter {
  new({required this.colors, this.stroke = 3, this.opacity = 1});

  final List<Color> colors;
  final double stroke;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true
      ..shader = SweepGradient(
        colors: [for (final c in colors) c.withValues(alpha: c.a * opacity)],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawCircle(
      rect.center,
      (math.min(size.width, size.height) - stroke) / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(VipStoryRingPainter old) =>
      !listEquals(old.colors, colors) ||
      old.stroke != stroke ||
      old.opacity != opacity;
}

/// D378 (STORY_RING): [child] (the picture) in the
/// member's ring — painted in the perk's colour, with the perk's art (300 ×
/// 300, its SVGA playing) over it when uploaded — [outerSize] across. A seen
/// story's ring is dimmed. Without the perk: [fallback].
class VipStoryRing extends ConsumerWidget {
  const new({
    required this.vip,
    required this.child,
    required this.fallback,
    super.key,
    this.outerSize = KSizes.storyRing,
    this.seen = false,
    this.stroke = 3,
  });

  final UserVip? vip;
  final Widget child;
  final Widget fallback;
  final double outerSize;
  final bool seen;
  final double stroke;

  static const ringKey = Key('vip.storyRing');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(vipLookProvider(vip));
    final colors = vipStoryRingColors(look);
    if (colors == null) return fallback;
    final perk = look!.perk(VipPerks.storyRing);
    final art = perk != null && (perk.still != null || perk.animation != null);
    return SizedBox.square(
      key: ringKey,
      dimension: outerSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: VipStoryRingPainter(
                colors: colors,
                stroke: stroke,
                opacity: seen ? 0.55 : 1,
              ),
            ),
          ),
          child,
          if (art)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: seen ? 0.55 : 1,
                  child: VipAnimatedArt(
                    animation: perk.animation,
                    still: perk.still,
                    animate: vipMotionAllowed(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- GLOWING_NAME -----------------------------------------------------------

/// D378 (§10.168.9, GLOWING_NAME): a glow in the tier's colour around a
/// member's name in the live chat, breathing slowly (1.8 s); reduce motion
/// (and the tests): a steady glow. Without the perk: [child] as it is.
class VipGlowingName extends ConsumerStatefulWidget {
  const new({required this.vip, required this.child, super.key});

  final UserVip? vip;
  final Widget child;

  static const glowKey = Key('vip.glowingName');

  /// The blur of the glow (logical pixels).
  static const double blur = 4;

  @override
  ConsumerState<VipGlowingName> createState() => _VipGlowingNameState();
}

class _VipGlowingNameState extends ConsumerState<VipGlowingName>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ref.watch(vipLookProvider(widget.vip));
    if (look == null || !look.vip.member || !look.has(VipPerks.glowingName)) {
      if (_pulse.isAnimating) _pulse.stop();
      return widget.child;
    }
    final motion = vipMotionAllowed(context);
    if (motion && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!motion && _pulse.isAnimating) {
      _pulse.stop();
    }
    final glowColor = Color.lerp(
      look.color.withValues(alpha: 1),
      const Color(0xFFFFFFFF),
      0.2,
    )!;
    Widget glow(double strength) => ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: VipGlowingName.blur,
        sigmaY: VipGlowingName.blur,
        tileMode: TileMode.decal,
      ),
      child: Opacity(
        opacity: strength,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(glowColor, BlendMode.srcIn),
          child: widget.child,
        ),
      ),
    );
    return Stack(
      key: VipGlowingName.glowKey,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: motion
                  ? AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, _) => glow(0.45 + 0.5 * _pulse.value),
                    )
                  : glow(0.85),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

// ---- DM_BUBBLE --------------------------------------------------------------

/// D378 (§10.168.10, DM_BUBBLE; owner: «هي نفس فقاعة التكست»): a member's
/// direct-message bubble in their tier's chat bubble — the CHAT_BUBBLE
/// perk's still (darkened), else deep shades of the tier's colour with a
/// light edge — or null without DM_BUBBLE (the usual bubble). The text on it
/// is white ([vipDmBubbleInk]).
BoxDecoration? vipDmBubbleDecoration(
  VipLook? look, {
  required BorderRadiusGeometry radius,
}) {
  if (look == null || !look.vip.member || !look.has(VipPerks.dmBubble)) {
    return null;
  }
  final still = look.perk(VipPerks.bubble)?.still;
  if (still != null) {
    return BoxDecoration(
      borderRadius: radius,
      image: DecorationImage(
        image: vipArtImage(still),
        fit: BoxFit.fill,
        colorFilter: const ColorFilter.mode(
          Color(0xB3000000),
          BlendMode.srcATop,
        ),
      ),
      border: Border.all(color: const Color(0xB3FFE08A), width: 0.8),
    );
  }
  final (top, bottom) = look.bubbleShades;
  return BoxDecoration(
    borderRadius: radius,
    gradient: LinearGradient(colors: [top, bottom]),
    border: Border.all(color: const Color(0xB3FFE08A), width: 0.8),
  );
}

/// The text on a VIP DM bubble (≥ 7:1 on its shades, D258).
const Color vipDmBubbleInk = Color(0xFFFFFFFF);

/// D378 (DM_BUBBLE): the animated CHAT_BUBBLE art over a member's DM bubble
/// (as in the live chat), or null.
Widget? vipDmBubbleArt(VipLook? look) =>
    look != null && look.vip.member && look.has(VipPerks.dmBubble)
    ? vipBubbleArt(look)
    : null;
