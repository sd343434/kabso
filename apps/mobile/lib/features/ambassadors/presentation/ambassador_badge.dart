import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The level's colours (D390, §10.179.9): two stops of a metal gradient and
/// the text on it. The four default levels have their own; any other code
/// (the OWNER may add levels) uses the brand's.
({Color from, Color to, Color ink}) ambassadorLevelColors(
  String code,
  KPalette p,
) => switch (code) {
  'BRONZE' => (
    from: const Color(0xFFE0A06A),
    to: const Color(0xFF9C5B2E),
    ink: const Color(0xFFFFFFFF),
  ),
  'SILVER' => (
    from: const Color(0xFFE8EBF0),
    to: const Color(0xFF9AA3AF),
    ink: const Color(0xFF1F2937),
  ),
  'GOLD' => (
    from: const Color(0xFFFFE08A),
    to: const Color(0xFFD4A017),
    ink: const Color(0xFF3B2A00),
  ),
  'DIAMOND' => (
    from: const Color(0xFF9EE7FF),
    to: const Color(0xFF3A8DDE),
    ink: const Color(0xFFFFFFFF),
  ),
  _ => (from: p.primary, to: p.primary, ink: p.onPrimary),
};

/// v1.140-social (D390, §10.179.9): the exclusive «سفير Kabso» badge — a
/// pill in the level's metal with a crest and the level's name. Its spoken
/// label is «سفير Kabso · {المستوى}». When the D389 badge explainer
/// (`KBadgeExplainer`) lands, wrap this widget in it (TODO in §10.179.9).
class AmbassadorBadge extends StatelessWidget {
  const new({required this.level, super.key, this.large = false});

  final String level;

  /// The dashboard's hero size (else the inline size).
  final bool large;

  static const badgeKey = Key('ambassador.badge');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = ambassadorLevelColors(level, context.palette);
    final name = l10n.ambLevelName(level);
    final h = large ? 30.0 : 22.0;
    return Semantics(
      label: l10n.ambBadgeLabel(name),
      excludeSemantics: true,
      child: Container(
        key: badgeKey,
        height: h,
        padding: EdgeInsetsDirectional.only(
          start: large ? 4 : 3,
          end: large ? KSpacing.md : KSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [c.from, c.to],
          ),
          boxShadow: [
            BoxShadow(
              color: c.to.withValues(alpha: 0.35),
              blurRadius: large ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: h - 6,
              height: h - 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.ink.withValues(alpha: 0.18),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: h - 10,
                color: c.ink,
              ),
            ),
            SizedBox(width: large ? 6 : 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (large
                          ? context.textStyles.bodyStrong
                          : context.textStyles.caption)
                      .copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
