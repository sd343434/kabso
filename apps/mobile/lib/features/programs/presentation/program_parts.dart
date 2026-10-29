import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Shared parts of the Me hub's program screens (D166): the Task Center,
/// the Event Center, SVIP and the recharge grid. Kabso tokens only (brand
/// red, gold `KBrandColors.gold`, the palette's surfaces).

/// The gold used on light and dark surfaces alike for text and strokes
/// (`KBrandColors.gold` deepened so it keeps contrast on white).
Color programGold(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? KBrandColors.gold
    : const Color(0xFFB7811A);

/// A rounded section card with a short accent bar before its [title]
/// (the reference's section headers) and an optional [trailing].
class ProgramSection extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.md),
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: KBrandColors.gold,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: t.title.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: KSpacing.xs),
            Text(subtitle, style: t.caption.copyWith(color: p.textSecondary)),
          ],
          const SizedBox(height: KSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// A coin amount: the Kabso coin and the number (Latin digits).
class CoinAmount extends StatelessWidget {
  const new(
    this.coins, {
    super.key,
    this.prefix = '',
    this.size = 16,
    this.style,
  });

  final int coins;
  final String prefix;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(AppIcons.coinGold, size: size, tint: false),
      const SizedBox(width: KSpacing.xxs),
      Text(
        '$prefix${KFormat.grouped(coins)}',
        textDirection: TextDirection.ltr,
        style:
            style ??
            context.textStyles.label.copyWith(
              color: context.palette.textPrimary,
            ),
      ),
    ],
  );
}

/// A small rounded tag («رائج», «انتهت», «قريباً», «عرض»).
class ProgramTag extends StatelessWidget {
  const new(this.label, {required this.color, super.key, this.onColor});

  final String label;
  final Color color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs + 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: context.textStyles.caption.copyWith(
        color: onColor ?? const Color(0xFFFFFFFF),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
    ),
  );
}

/// The pill action of a task row: «اذهب», «استلام» or «تم» (disabled), at
/// least 44 lp tall.
class ProgramPillButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.filled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Filled brand red (claim) or outlined (go).
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;
    final bg = filled ? p.primary : Colors.transparent;
    final fg = filled ? p.onPrimary : p.primaryText;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 76, minHeight: 44),
        child: Material(
          color: enabled ? bg : p.surfaceOverlay,
          shape: StadiumBorder(
            side: filled || !enabled
                ? BorderSide.none
                : BorderSide(color: p.primaryText),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.lg,
                vertical: KSpacing.sm,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: loading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      )
                    : Text(
                        label,
                        maxLines: 1,
                        style: context.textStyles.label.copyWith(
                          color: enabled ? fg : p.textTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tinted round tile with an icon (task rows, perks, events).
class ProgramIconTile extends StatelessWidget {
  const new({required this.icon, required this.hue, super.key, this.size = 44});

  final IconData icon;
  final Color hue;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: hue.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(KRadius.md),
    ),
    child: SizedBox.square(
      dimension: size,
      child: Icon(icon, size: size * 0.55, color: hue),
    ),
  );
}

/// Token hues for icons and calendar bars (Kabso palette tones).
abstract final class ProgramHues {
  static const List<Color> all = [
    KBrandColors.red500,
    Color(0xFFE0A21B),
    Color(0xFF14B8A6),
    Color(0xFF4DA3FF),
    Color(0xFFFF3B6B),
    Color(0xFFF5A623),
  ];

  /// A stable hue for [id] (the same event keeps its colour).
  static Color of(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return all[hash % all.length];
  }
}
