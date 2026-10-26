import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// Shared pieces of the families v2 screens (CP-022, D116): colours, the
// gold pill button, rank medals, role chips, presence and "Soon" badges.
// The look follows the owner's style board (kept outside git, look only);
// the art is Kabso's own (assets/leaderboard, assets/icons) and the slots
// for the owner's coming family art are in [FamilyArt].

/// Slots for the owner's family art (CP-022, D116: "the owner will supply
/// Kabso art later"). Each is null until the file lands under
/// `assets/families/` (see its PROVENANCE.md); the screens draw gradients
/// and shapes meanwhile, never third-party art.
abstract final class FamilyArt {
  /// The family page's hero background behind the cover (when no cover).
  static String? get heroBackground => null;

  /// The podium cards behind places 1–3 (index 0 = first place).
  static const List<String?> podiumCards = [null, null, null];

  /// The level crown on the level chip.
  static String? get levelCrown => null;

  /// The five tool tiles: manage, join requests, competitions, shop, tasks.
  static const List<String?> toolIcons = [null, null, null, null, null];

  /// Kabso's own winged crowned ring around a podium emblem (D84 art).
  static String podiumFrame(int place) =>
      'assets/leaderboard/podium_frame_$place.webp';

  /// Kabso's own gold, silver and bronze shields (D84 art).
  static String rankShield(int place) =>
      'assets/leaderboard/rank_shield_$place.webp';
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

/// The gold pill ("Join +", "Invite members"). [onPressed] null = off.
class FamilyGoldButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.height = 36,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final enabled = onPressed != null && !busy;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFFFFFF),
            ),
          )
        else if (icon case final icon?)
          Icon(icon, size: 18, color: const Color(0xFFFFFFFF)),
        if (busy || icon != null) const SizedBox(width: KSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodyStrong.copyWith(
              color: const Color(0xFFFFFFFF),
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
              gradient: FamilyColors.goldGradient,
              borderRadius: BorderRadius.circular(KRadius.pill),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33D98E28),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(KRadius.pill),
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
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
/// then the number alone.
class FamilyRankMedal extends StatelessWidget {
  const new({required this.rank, super.key, this.size = 30});

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
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: t.bodyStrong.copyWith(color: p.textSecondary),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size * 1.2,
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

/// A member's role on a soft pill (leader gold, deputy lavender, member
/// grey).
class FamilyRoleChip extends StatelessWidget {
  const new({required this.role, super.key});

  final FamilyRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final (bg, fg, label) = switch (role) {
      FamilyRole.leader => (
        const Color(0xFFFCE3A8),
        FamilyColors.goldText,
        l10n.familyRoleLeader,
      ),
      FamilyRole.deputy => (
        const Color(0xFFE6DDFB),
        const Color(0xFF5B3FB0),
        l10n.familyRoleDeputy,
      ),
      FamilyRole.member => (
        p.surfaceRaised,
        p.textSecondary,
        l10n.familyRoleMember,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.textStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.caption.copyWith(color: p.textSecondary),
          ),
        ),
        const SizedBox(width: KSpacing.xs),
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

/// The level chip: a crown and "Level N" on a dark glass pill (the hero).
class FamilyLevelCrownChip extends StatelessWidget {
  const new({required this.level, super.key});

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: KSpacing.md,
      vertical: KSpacing.xs + 2,
    ),
    decoration: BoxDecoration(
      color: const Color(0x66000000),
      border: Border.all(color: FamilyColors.gold, width: 1.2),
      borderRadius: BorderRadius.circular(KRadius.md),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (FamilyArt.levelCrown case final art?)
          Image.asset(art, width: 22, height: 22)
        else
          const AppIcon(
            AppIcons.crownFilled,
            size: 20,
            color: FamilyColors.gold,
          ),
        const SizedBox(width: KSpacing.xs),
        Flexible(
          child: Text(
            context.l10n.familyLevelLong(level),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodyStrong.copyWith(
              color: const Color(0xFFFFFFFF),
            ),
          ),
        ),
      ],
    ),
  );
}
