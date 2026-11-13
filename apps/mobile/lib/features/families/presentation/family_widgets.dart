import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// Shared pieces of the families v2 screens (CP-022, D116): colours, the
// gold pill button, rank medals, role chips, presence and "Soon" badges.
// The look follows the owner's style board (kept outside git, look only);
// the art is Kabso's own (assets/leaderboard, assets/icons) and the
// owner's family art (assets/families, D125) is placed through [FamilyArt].

/// Slots for the owner's family art (CP-022, D116; D125: the hero banner
/// and the three podium cards landed under `assets/families/`, see its
/// PROVENANCE.md). The empty places in each picture (the circle for the
/// emblem, the panel for the text) are in the image's own pixels, measured
/// on the files with a flood fill and a circle fit (D125).
/// Slots still null are drawn with gradients and shapes, never third-party
/// art.
abstract final class FamilyArt {
  /// The family page's default cover when the leader set none (D125):
  /// 1860 × 845, opaque. The gold ring on the right holds the emblem, the
  /// dark-red panel on the left the name, level and number. Never mirrored.
  static const hero = FamilyArtSlots(
    asset: 'assets/families/hero_banner.webp',
    size: Size(1860, 845),
    circleCentre: Offset(1625, 475),
    // The ring's inner edge is 111–137 px from the centre; the emblem
    // stays just inside it.
    circleRadius: 118,
    // The plain part of the panel (the film strip and the curtain cross
    // its left end and its bottom).
    panel: Rect.fromLTRB(400, 235, 1110, 560),
  );

  /// The podium cards of places 1–3 (index 0 = first place; D125): 640 px
  /// wide, transparent around the frame. The circle at the top holds the
  /// emblem, the panel below the place, name, level, points and Join.
  static const List<FamilyArtSlots> podiumCards = [
    FamilyArtSlots(
      asset: 'assets/families/podium_1.webp',
      size: Size(640, 855),
      circleCentre: Offset(320, 293),
      circleRadius: 114,
      panel: Rect.fromLTRB(140, 492, 500, 690),
    ),
    FamilyArtSlots(
      asset: 'assets/families/podium_2.webp',
      size: Size(640, 919),
      circleCentre: Offset(320, 292),
      circleRadius: 136,
      panel: Rect.fromLTRB(172, 520, 468, 752),
    ),
    FamilyArtSlots(
      asset: 'assets/families/podium_3.webp',
      size: Size(640, 923),
      circleCentre: Offset(320, 285),
      circleRadius: 130,
      panel: Rect.fromLTRB(168, 506, 472, 740),
    ),
  ];

  /// The families list's "monthly ranking" activity card (D127): the left
  /// part (950 × 500 of 1500 × 500, no lettering) of the owner's families
  /// banner, 570 × 300.
  static const activityMonthly = 'assets/families/activity_monthly.webp';

  /// The level crown on the level chip.
  static String? get levelCrown => null;

  /// The five tool tiles: manage, join requests, competitions, shop, tasks.
  static const List<String?> toolIcons = [null, null, null, null, null];

  /// Kabso's own gold, silver and bronze shields (D84 art).
  static String rankShield(int place) =>
      'assets/leaderboard/rank_shield_$place.webp';
}

/// A picture of the owner's family art and its empty places, in the
/// image's pixels (D125).
@immutable
class FamilyArtSlots {
  const new({
    required this.asset,
    required this.size,
    required this.circleCentre,
    required this.circleRadius,
    required this.panel,
  });

  final String asset;

  /// The image's size in pixels.
  final Size size;

  /// The empty circle for the emblem.
  final Offset circleCentre;
  final double circleRadius;

  /// The empty panel for the text.
  final Rect panel;

  /// Where the picture lands at the full width of [box], on its bottom
  /// edge (the box may be taller; the picture keeps its aspect).
  Rect fitWidthIn(Size box) {
    final h = box.width * size.height / size.width;
    return Rect.fromLTWH(0, box.height - h, box.width, h);
  }

  /// [r] (image pixels) in a box where the picture is drawn at [drawn].
  Rect map(Rect r, Rect drawn) {
    final s = drawn.width / size.width;
    return Rect.fromLTRB(
      drawn.left + r.left * s,
      drawn.top + r.top * s,
      drawn.left + r.right * s,
      drawn.top + r.bottom * s,
    );
  }

  /// The emblem's circle in a box where the picture is drawn at [drawn].
  Rect circleIn(Rect drawn) =>
      map(Rect.fromCircle(center: circleCentre, radius: circleRadius), drawn);
}

/// Fixed accent colours of the family screens (both themes).
abstract final class FamilyColors {
  static const gold = Color(0xFFF2B84B);
  static const goldDeep = Color(0xFFD98E28);
  static const goldText = Color(0xFF8A5A00);
  static const onGold = Color(0xFF3A2500);
  static const online = Color(0xFF2BBE62);
  static const goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8CB6A), Color(0xFFE4A23C)],
  );

  /// The owner's mockup (D127): Join, Invite and the selected board tab,
  /// measured #F9C570 → #DEA350.
  static const buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF7C673), Color(0xFFDE9F4E)],
  );

  /// The level progress fill (measured #DA8A2E → #F9CB6D).
  static const progressGradient = LinearGradient(
    colors: [Color(0xFFDA8A2E), Color(0xFFF9CB6D)],
  );

  /// The level tag on a list row (the mockup's red tier text).
  static const levelRed = Color(0xFFD32F2F);
  static const levelRedOnDark = Color(0xFFFF6B6B);

  /// Dark text on the gold Invite button (measured on the mockup).
  static const onGoldButton = Color(0xFF1C1C28);

  /// The podium's backdrop (light: measured #FEF7EC → #F8E7D2; dark: an
  /// adapted warm brown).
  static const podiumBackdropLight = [Color(0xFFFEF7EC), Color(0xFFF8E7D2)];
  static const podiumBackdropDark = [Color(0xFF2A2117), Color(0xFF1D1610)];

  /// The podium card colours of places 1, 2 and 3 (top, bottom).
  static const List<(Color, Color)> podium = [
    (Color(0xFFE5513F), Color(0xFFA92019)),
    (Color(0xFF5B95F7), Color(0xFF2B57CC)),
    (Color(0xFFF6A55A), Color(0xFFD5672A)),
  ];

  /// The hero's gradient while there is no cover (deep wine to gold).
  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3B0D12), Color(0xFF7A1E1E), Color(0xFFB0702A)],
  );
}

/// Compact counts like "12.4K" (Latin digits, never overstated).
String familyCount(BuildContext context, int value) =>
    KFormat.compact(value, context.l10n);

/// The gold pill ("+ Join", "Invite members"). [onPressed] null = off.
/// The icon stays on the left of the label in both directions, as on the
/// owner's mockup (D127).
class FamilyGoldButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.height = 36,
    this.expand = false,
    this.busy = false,
    this.foreground = const Color(0xFFFFFFFF),
    this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.radius = KRadius.pill,
    this.iconSize = 18,
    this.horizontalPadding = KSpacing.md,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;
  final bool busy;
  final Color foreground;
  final double? fontSize;
  final FontWeight fontWeight;
  final double radius;
  final double iconSize;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final enabled = onPressed != null && !busy;
    final content = Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else if (icon case final icon?)
          Icon(icon, size: iconSize, color: foreground),
        if (busy || icon != null) const SizedBox(width: KSpacing.xs + 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodyStrong.copyWith(
              color: foreground,
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.45,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              gradient: FamilyColors.buttonGradient,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33D98E28),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A place: the gold, silver or bronze shield with its number for 1–3,
/// then the number on a light grey disc (D127, the owner's mockup).
class FamilyRankMedal extends StatelessWidget {
  const new({required this.rank, super.key, this.size = 32});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final label = KFormat.grouped(rank);
    if (rank < 1 || rank > 3) {
      return SizedBox(
        width: size,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(KRadius.pill),
              border: Border.all(color: p.surfaceOverlay, width: 0.5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: t.bodyStrong.copyWith(
                  color: p.textPrimary,
                  fontSize: 15,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            FamilyArt.rankShield(rank),
            width: size,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          Text(
            label,
            style: t.bodyStrong.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Color(0x88000000), blurRadius: 2)],
            ),
          ),
        ],
      ),
    );
  }
}

/// A member's role on a soft pill (D127, measured on the owner's mockup:
/// leader gold #FBC975, deputy lavender #E5D3FE, member grey #F1F3F4; the
/// mockup's blue "moderator" has no role in Kabso).
class FamilyRoleChip extends StatelessWidget {
  const new({required this.role, super.key});

  final FamilyRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, label) = switch (role) {
      FamilyRole.leader => (
        const Color(0xFFFBC975),
        const Color(0xFF4A3000),
        l10n.familyRoleLeader,
      ),
      FamilyRole.deputy => (
        const Color(0xFFE5D3FE),
        const Color(0xFF45238F),
        l10n.familyRoleDeputy,
      ),
      FamilyRole.member => (
        dark ? p.surfaceOverlay : const Color(0xFFF1F3F4),
        p.textPrimary,
        l10n.familyRoleMember,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.caption.copyWith(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

/// A family's emblem in the gold hexagon of the list rows (D127, the
/// owner's mockup: pointy-top hexagon, gold edge).
class FamilyHexEmblem extends StatelessWidget {
  const new({required this.url, super.key, this.width = 47});

  final String? url;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.12;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: const _HexEdgePainter(),
        child: Padding(
          padding: const EdgeInsets.all(3.5),
          child: ClipPath(
            clipper: const _HexClipper(),
            child: FamilyEmblemSquare(url: url),
          ),
        ),
      ),
    );
  }
}

/// The emblem filling its box (no circle), for clipped frames.
class FamilyEmblemSquare extends StatelessWidget {
  const new({required this.url, super.key});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFFFF4DA),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Image.asset(
          'assets/leaderboard/rank_shield_1.webp',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
    final url = this.url;
    if (url == null) return SizedBox.expand(child: fallback);
    return SizedBox.expand(
      child: Image.network(
        url,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

Path _hexPath(Size size) {
  final w = size.width;
  final h = size.height;
  return Path()
    ..moveTo(w / 2, 0)
    ..lineTo(w, h * 0.25)
    ..lineTo(w, h * 0.75)
    ..lineTo(w / 2, h)
    ..lineTo(0, h * 0.75)
    ..lineTo(0, h * 0.25)
    ..close();
}

class _HexClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) => _hexPath(size);

  @override
  bool shouldReclip(_HexClipper oldClipper) => false;
}

class _HexEdgePainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas
      ..drawPath(path, Paint()..color = const Color(0xFFFFF6E2))
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6D28A), Color(0xFFD99A3E)],
          ).createShader(Offset.zero & size),
      );
  }

  @override
  bool shouldRepaint(_HexEdgePainter oldDelegate) => false;
}

/// "Online now" with a green dot, or "x ago" with a grey one; nothing when
/// the presence is hidden (§10.25).
class FamilyPresenceLabel extends StatelessWidget {
  const new({required this.presence, super.key, this.now});

  final FamilyPresence? presence;

  /// The time to measure "ago" from (tests); the clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final presence = this.presence;
    if (presence == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final p = context.palette;
    final at = presence.lastActiveAt;
    final String text;
    if (presence.online) {
      text = l10n.familyOnlineNow;
    } else if (at == null) {
      return const SizedBox.shrink();
    } else {
      text =
          KFormat.relative(
            at,
            now ?? DateTime.now(),
            l10n,
            Localizations.localeOf(context).toLanguageTag(),
          ) ??
          l10n.familyActiveJustNow;
    }
    // D127: the text, then the dot on its right (the owner's mockup).
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.caption.copyWith(
              color: p.textTertiary,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: KSpacing.sm + 2),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: presence.online ? FamilyColors.online : p.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// A small "Soon" tag on a feature that is not built (D62 convention:
/// greyed, labelled, not a button).
class FamilySoonBadge extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Text(
        context.l10n.familySoon,
        maxLines: 1,
        style: context.textStyles.caption.copyWith(
          color: p.textSecondary,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}

/// The hero's level chip (D127, the owner's mockup): a gold crown and
/// "Level N" on a dark glass box with a gold edge, corners 8.
class FamilyLevelCrownChip extends StatelessWidget {
  const new({required this.level, super.key});

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm + 2),
    decoration: BoxDecoration(
      color: const Color(0x80140A04),
      border: Border.all(color: const Color(0xFFE9B54F)),
      borderRadius: BorderRadius.circular(KRadius.sm),
    ),
    child: Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (FamilyArt.levelCrown case final art?)
          Image.asset(art, width: 20, height: 20)
        else
          const AppIcon(
            AppIcons.crownFilled,
            size: 20,
            color: FamilyColors.gold,
          ),
        const SizedBox(width: KSpacing.sm),
        Flexible(
          child: Text(
            context.l10n.familyLevel(level),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodyStrong.copyWith(
              color: const Color(0xFFFFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ],
    ),
  );
}
