import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:material_ui/material_ui.dart';

/// D258 (the owner's VIP 1 perks, §10.94): what a member wears wherever
/// people are shown — the badge beside the name, the animated avatar frame,
/// the name colour and the chat bubble. Everything comes from the member's
/// `UserSummary.vip` and the session's VIP catalogue; nothing is shown
/// without a VIP.

/// The VIP badge beside a name ([height] tall): the owner's badge art, else a
/// small «VIPn» pill in the tier's colour.
class VipNameBadge extends ConsumerWidget {
  const new({required this.vip, required this.height, super.key});

  final UserVip? vip;
  final double height;

  static const badgeKey = Key('vip.nameBadge');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(vipLookProvider(vip));
    if (look == null || (look.tier != null && !look.has(VipPerks.badge))) {
      return const SizedBox.shrink();
    }
    final art = look.badgeArt;
    if (art.still != null || art.animation != null) {
      // The owner's medal is square (`svip_medals`, 500 × 500): drawn 1.6 ×
      // the line's tag height, overflowing the line without growing it.
      return SizedBox(
        key: badgeKey,
        height: height,
        width: height * 1.6,
        child: OverflowBox(
          maxWidth: height * 1.6,
          maxHeight: height * 1.6,
          child: VipAnimatedArt(animation: art.animation, still: art.still),
        ),
      );
    }
    return Container(
      key: badgeKey,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        // Deep shades of the tier's colour: the white «VIPn» stays ≥ 7:1.
        gradient: LinearGradient(
          colors: [look.bubbleShades.$1, look.bubbleShades.$2],
        ),
        border: Border.all(color: const Color(0xCCFFE08A), width: 0.8),
      ),
      child: Text(
        'VIP${look.level}',
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: height * 0.6,
          height: 1,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          color: const Color(0xFFFFFFFF),
          shadows: const [Shadow(color: Color(0x66000000), blurRadius: 2)],
        ),
      ),
    );
  }
}

/// The animated VIP avatar frame around [child] (a round picture [size]
/// across): the AVATAR_FRAME perk's art sized and placed so its round window
/// fits the picture (a hair larger: no gap). The window is measured on the
/// device from the decoded SVGA's transparent middle (once per art); until
/// then, and for a still, the owner's template's window. Without the perk
/// (or its art) only [child].
class VipAvatarFrame extends ConsumerWidget {
  const new({
    required this.vip,
    required this.size,
    required this.child,
    super.key,
  });

  final UserVip? vip;
  final double size;
  final Widget child;

  /// The owner's frame template (`svip_1_frame`, 500 × 500): the window's
  /// centre (249, 227) and its smallest diameter across the frames, 260.
  static const templateCentre = Offset(0.498, 0.454);
  static const double templateWindow = 0.52;

  /// How much of the window's rim the picture covers (no gap).
  static const double overlap = 1.03;

  static const frameKey = Key('vip.avatarFrame');

  /// The art's box for a picture [size] across, for a window at [centre]
  /// of [diameter] (fractions of the art), relative to the picture's box.
  static Rect artRect(double size, Offset centre, double diameter) {
    // The window comes out a hair smaller than the picture: no gap.
    final outer = size / (diameter * overlap);
    return Rect.fromLTWH(
      size / 2 - centre.dx * outer,
      size / 2 - centre.dy * outer,
      outer,
      outer,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perk = ref.watch(vipLookProvider(vip))?.perk(VipPerks.avatarFrame);
    if (perk == null || (perk.still == null && perk.animation == null)) {
      return child;
    }
    return SizedBox.square(
      dimension: size,
      child: _FittedFrame(perk: perk, size: size, child: child),
    );
  }
}

class _FittedFrame extends StatefulWidget {
  const new({required this.perk, required this.size, required this.child});

  final VipPerk perk;
  final double size;
  final Widget child;

  @override
  State<_FittedFrame> createState() => _FittedFrameState();
}

class _FittedFrameState extends State<_FittedFrame> {
  Offset _centre = VipAvatarFrame.templateCentre;
  double _diameter = VipAvatarFrame.templateWindow;
  String? _measured;

  void _measure(double side) {
    final url = widget.perk.animation;
    if (url == null || !vipPlays(widget.perk) || _measured == url) return;
    _measured = url;
    unawaited(() async {
      final clip = await VipSvgaCache.load(url, maxSide: side);
      final window = await clip?.window();
      if (window == null || !mounted) return;
      setState(() {
        _centre = window.centre;
        _diameter = window.diameter;
      });
    }());
  }

  @override
  Widget build(BuildContext context) {
    final rect = VipAvatarFrame.artRect(widget.size, _centre, _diameter);
    _measure(rect.width * MediaQuery.devicePixelRatioOf(context));
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        widget.child,
        Positioned.fromRect(
          key: VipAvatarFrame.frameKey,
          rect: rect,
          child: IgnorePointer(
            child: VipAnimatedArt(
              animation: widget.perk.animation,
              still: widget.perk.still,
            ),
          ),
        ),
      ],
    );
  }
}

/// D258: the CHAT_BUBBLE decoration of a member's chat line: the perk's still
/// stretched over the line (darkened), else a bubble in deep shades of the
/// tier's colour (a light edge); null without the perk.
BoxDecoration? vipBubbleDecoration(VipLook? look, {required double radius}) {
  final perk = look?.perk(VipPerks.bubble);
  if (look == null || perk == null) return null;
  final still = perk.still;
  // The animated bubble plays over the plain one (vipBubbleArt).
  if (still != null && !vipPlays(perk)) {
    // The owner's art is darkened so the white text and the name read on it.
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      image: DecorationImage(
        image: vipArtImage(still),
        fit: BoxFit.fill,
        colorFilter: const ColorFilter.mode(
          Color(0xB3000000),
          BlendMode.srcATop,
        ),
      ),
    );
  }
  // Opaque deep shades of the tier's colour: the name tint (vipNameTint) and
  // the white text stay ≥ 4.5:1 on it whatever the tier's colour.
  final (top, bottom) = look.bubbleShades;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(colors: [top, bottom]),
    border: Border.all(color: const Color(0xB3FFE08A), width: 0.8),
  );
}

/// Whether [perk]'s hosted SVGA plays here (not in widget tests).
bool vipPlays(VipPerk perk) =>
    VipSvga.enabled &&
    VipAnimatedArt.animationsEnabled &&
    (perk.animation?.startsWith('http') ?? false);

/// D258: the owner's animated CHAT_BUBBLE (its SVGA 9-sliced to the line:
/// the frame follows the line's edge, the ornaments overflow it), drawn
/// over the plain bubble and under the text; null without one.
Widget? vipBubbleArt(VipLook? look) {
  final perk = look?.perk(VipPerks.bubble);
  if (perk == null || !vipPlays(perk)) return null;
  return VipSvga(url: perk.animation!, nine: VipSvgaNine.bubble);
}

/// D258: the PROFILE_CARD art behind a member's person card, or null.
VipPerk? vipCardPerk(VipLook? look) {
  final perk = look?.perk(VipPerks.profileCard);
  final none = perk == null || (perk.still == null && perk.animation == null);
  return none ? null : perk;
}

/// D258 (MIC_WAVE): while a VIP member speaks on a seat, the owner's wave
/// art ([scale] × the picture) plays behind their picture instead of the
/// plain glow ([fallback]). Without the perk (or its art), or not
/// speaking: [fallback].
class VipMicWave extends ConsumerWidget {
  const new({
    required this.vip,
    required this.speaking,
    required this.size,
    required this.child,
    required this.fallback,
    super.key,
    this.scale = 1.7,
  });

  final UserVip? vip;
  final bool speaking;
  final double size;
  final Widget child;
  final Widget fallback;
  final double scale;

  static const waveKey = Key('vip.micWave');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!speaking || vip == null) return fallback;
    final perk = ref.watch(vipLookProvider(vip))?.perk(VipPerks.micWave);
    if (perk == null || (perk.still == null && perk.animation == null)) {
      return fallback;
    }
    final outer = size * scale;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            key: waveKey,
            left: (size - outer) / 2,
            top: (size - outer) / 2,
            width: outer,
            height: outer,
            child: IgnorePointer(
              child: VipAnimatedArt(
                animation: perk.animation,
                still: perk.still,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
