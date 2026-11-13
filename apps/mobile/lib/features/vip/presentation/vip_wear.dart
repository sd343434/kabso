import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/components/k_badge_explainer.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D258 (the owner's VIP 1 perks, §10.94): what a member wears wherever
/// people are shown — the badge beside the name, the animated avatar frame,
/// the name colour and the chat bubble. Everything comes from the member's
/// `UserSummary.vip` and the session's VIP catalogue; nothing is shown
/// without a VIP.

/// The VIP badge after a name ([height] tall, the row's emblem height).
/// D268 (owner: «ايقونة vip دائماً تأتي بعد الاسم وازل الميدالية التي قبل
/// الاسم»): always right AFTER the name, nothing VIP before it — the BADGE
/// perk's own art («شارة بجانب الاسم», a wide pill) at its natural width
/// (never squeezed into a square; its transparent sides trimmed so the gaps
/// beside it are the row's own), else a small «VIPn» pill in the tier's
/// colour. The tier's central medal is not shown beside a name.
class VipNameBadge extends ConsumerWidget {
  const new({
    required this.vip,
    required this.height,
    this.pillHeight,
    this.perk = VipPerks.badge,
    this.explain = true,
    super.key,
  });

  /// D388: a tap shows what the badge is («عضوية VIP 3»).
  final bool explain;

  final UserVip? vip;

  /// The perk that shows it: BADGE (chat, seats, cards) or, D378
  /// (§10.168.8), POST_BADGE (after the name on posts, reels and comments
  /// — the same art: the BADGE perk's when held, else the «VIPn» pill).
  final String perk;

  /// The art's height.
  final double height;

  /// D284: the «VIPn» pill's height without art ([height] when unset) — a
  /// chat line's tag height, as the art's bar.
  final double? pillHeight;

  static const badgeKey = Key('vip.nameBadge');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(vipLookProvider(vip));
    // D270: a store-only look (no membership) has no badge.
    if (look == null ||
        !look.vip.member ||
        (look.tier != null && !look.has(perk))) {
      return const SizedBox.shrink();
    }
    return KBadgeExplainer(
      message: context.l10n.badgeExplainVip(look.level),
      enabled: explain,
      child: _art(look),
    );
  }

  Widget _art(VipLook look) {
    if (look.nameBadgeArt case final art?) {
      return _NameBadgeArt(
        key: badgeKey,
        animation: art.animation,
        still: art.still,
        aspect: art.aspect,
        height: this.height,
      );
    }
    final height = pillHeight ?? this.height;
    return Container(
      key: badgeKey,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        // Deep shades of the tier's colour: the white «VIPn» stays ≥ 7:1.
        gradient: LinearGradient(
          colors: [look.bubbleShades.$1, look.bubbleShades.$2],
        ),
        border: Border.all(color: const Color(0xCCFFE08A), width: 0.8),
      ),
      // D278: as wide as the text (an alignment would fill a Wrap's line).
      child: Center(
        widthFactor: 1,
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
      ),
    );
  }
}

/// D268: the name badge's art [height] tall at its natural width
/// ([aspect] × [height]), its transparent sides trimmed: measured once per
/// still (the columns with any visible pixel), the whole box until then.
class _NameBadgeArt extends StatefulWidget {
  const new({
    required this.animation,
    required this.still,
    required this.aspect,
    required this.height,
    super.key,
  });

  final String? animation;
  final String? still;
  final double aspect;
  final double height;

  /// The visible columns of each still measured (fractions of its width).
  static final Map<String, (double, double)> _visible = {};

  @override
  State<_NameBadgeArt> createState() => _NameBadgeArtState();
}

class _NameBadgeArtState extends State<_NameBadgeArt> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  @override
  void didUpdateWidget(_NameBadgeArt old) {
    super.didUpdateWidget(old);
    if (old.still != widget.still) _measure();
  }

  void _measure() {
    _stop();
    final still = widget.still;
    if (still == null || _NameBadgeArt._visible.containsKey(still)) return;
    final stream = vipArtImage(still)
        .resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      _stop();
      unawaited(() async {
        final cols = await _visibleColumns(info.image);
        info.dispose();
        if (cols == null) return;
        _NameBadgeArt._visible[still] = cols;
        if (mounted && widget.still == still) setState(() {});
      }());
    }, onError: (_, _) => _stop());
    _stream = stream..addListener(listener);
    _listener = listener;
  }

  void _stop() {
    if (_listener case final l?) _stream?.removeListener(l);
    _stream = null;
    _listener = null;
  }

  /// The first and last columns (fractions) with a pixel over 3 % opaque.
  static Future<(double, double)?> _visibleColumns(ui.Image image) async {
    final data = await image.toByteData();
    if (data == null) return null;
    final w = image.width;
    final h = image.height;
    bool seen(int x) {
      for (var y = 0; y < h; y += 2) {
        if (data.getUint8((y * w + x) * 4 + 3) > 8) return true;
      }
      return false;
    }

    var l = 0;
    while (l < w && !seen(l)) {
      l++;
    }
    if (l >= w) return null;
    var r = w - 1;
    while (r > l && !seen(r)) {
      r--;
    }
    return (l / w, (r + 1) / w);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.height * widget.aspect;
    final (l, r) = _NameBadgeArt._visible[widget.still] ?? (0.0, 1.0);
    return SizedBox(
      width: full * (r - l),
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -full * l,
            top: 0,
            width: full,
            height: widget.height,
            child: VipAnimatedArt(
              animation: widget.animation,
              still: widget.still,
            ),
          ),
        ],
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

  /// The owner's frame (`svip_1_frame`, 500 × 500), measured from its
  /// SVGA as [VipSvgaClip.window] does (D265): the smallest circle holding
  /// its whole opening is 0.685 of the canvas across, centred. (D258's
  /// 0.584 was the opening's narrowest width: the picture left the
  /// opening's corners empty.)
  static const templateCentre = Offset(0.5, 0.5);
  static const double templateWindow = 0.685;

  /// How much of the window's rim the picture covers (no gap).
  static const double overlap = 1.02;

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

  /// Whether [vip]'s frame is drawn (its perk has art): the picture then
  /// goes in bare (D265: no ring of its own between it and the frame).
  static bool shows(WidgetRef ref, UserVip? vip) {
    if (vip == null) return false;
    final perk = ref.watch(vipLookProvider(vip))?.perk(VipPerks.avatarFrame);
    return perk != null && (perk.still != null || perk.animation != null);
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
              video: widget.perk.video,
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

/// Whether [perk]'s hosted SVGA plays here (not in widget tests). D270: an
/// MP4 (a store item's art) never does — [VipAnimatedArt] plays it.
bool vipPlays(VipPerk perk) =>
    VipSvga.enabled &&
    VipAnimatedArt.animationsEnabled &&
    perk.video == null &&
    (perk.animation?.startsWith('http') ?? false);

/// D270: whether [perk]'s hosted MP4 (a store item's art) plays here.
bool vipPlaysVideo(VipPerk perk) =>
    VipAnimatedArt.animationsEnabled &&
    perk.video != null &&
    (perk.animation?.startsWith('http') ?? false);

/// D258: the owner's animated CHAT_BUBBLE (its SVGA 9-sliced to the line:
/// the frame follows the line's edge, the ornaments overflow it), drawn
/// over the plain bubble and under the text; null without one.
Widget? vipBubbleArt(VipLook? look) {
  final perk = look?.perk(VipPerks.bubble);
  if (perk == null) return null;
  // D270: a store bubble's MP4 is stretched over the line (no 9-slice).
  if (vipPlaysVideo(perk)) {
    return VipAnimatedArt(
      animation: perk.animation,
      still: perk.still,
      video: perk.video,
      fit: BoxFit.fill,
    );
  }
  if (!vipPlays(perk)) return null;
  return VipSvga(url: perk.animation!, nine: VipSvgaNine.bubble);
}

/// D383 (owner 2026-11-12: «تغير لون خلفية او تكون خلفية فيها عناصر
/// متحركة»): the PROFILE_CARD perk is the person card's background, no
/// longer a box or frame around it — a colour (the perk's `value`,
/// `#RRGGBB`) and / or an art filling the card behind its content (an SVGA,
/// else the perk's MP4, else its still; a store card's art the same way).
/// Null without the perk, or with neither a colour nor an art.
typedef VipCardBackground = ({Color? color, VipPerk? art});

VipCardBackground? vipCardBackground(VipLook? look) {
  final perk = look?.perk(VipPerks.profileCard);
  if (perk == null) return null;
  final color = vipHexColor(perk.value);
  final hasArt =
      perk.still != null || perk.animation != null || perk.videoUrl != null;
  if (color == null && !hasArt) return null;
  return (color: color, art: hasArt ? perk : null);
}

/// `#RRGGBB` → an opaque colour; anything else → null.
Color? vipHexColor(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(value);
  if (m == null) return null;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
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

/// D258 (CHAT_NAME_COLOR, owner): a member's name (or line) in their
/// tier's special colour — one solid colour set in the panel, apart from the
/// tier's theme colour (VIP 1 #FFC928 since D268, was #FFD12E): no gradient, no
/// outline, no shadow (owner). Exactly the text's own colour replaced, as a
/// `TextStyle(color:)` would; without the perk or a colour: [child].
class VipNameShimmer extends ConsumerWidget {
  const new({required this.vip, required this.child, super.key});

  final UserVip? vip;
  final Widget child;

  static const shimmerKey = Key('vip.nameShimmer');

  /// [vip]'s special text colour now, or null.
  static Color? colorOf(WidgetRef ref, UserVip? vip) {
    final look = ref.watch(vipLookProvider(vip));
    if (look == null || !look.has(VipPerks.nameColor)) return null;
    return look.specialColor;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorOf(ref, vip);
    if (color == null) return child;
    return ColorFiltered(
      key: shimmerKey,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: child,
    );
  }
}
