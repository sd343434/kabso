import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
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
      return SizedBox(
        key: badgeKey,
        height: height,
        width: height * 1.6,
        child: VipAnimatedArt(animation: art.animation, still: art.still),
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
/// across): the AVATAR_FRAME perk's art drawn [scale] × larger, over the
/// picture. Without the perk (or its art) only [child].
class VipAvatarFrame extends ConsumerWidget {
  const new({
    required this.vip,
    required this.size,
    required this.child,
    super.key,
    this.scale = 1.42,
  });

  final UserVip? vip;
  final double size;
  final Widget child;
  final double scale;

  static const frameKey = Key('vip.avatarFrame');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perk = ref.watch(vipLookProvider(vip))?.perk(VipPerks.avatarFrame);
    if (perk == null || (perk.still == null && perk.animation == null)) {
      return child;
    }
    final outer = size * scale;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          child,
          Positioned(
            key: frameKey,
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
        ],
      ),
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
  if (still != null) {
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
