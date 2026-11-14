import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The codes of the levels before the owner's «سفراء النجوم» names (D390
/// follow-up, owner 2026-11-14) and the code each became. Migration
/// `20270520090000_ambassador_level_names` renames them in the database; an
/// older value (a cached response, an old audit row) still reads as the new
/// level here.
const Map<String, String> ambassadorLegacyLevelCodes = {
  'BRONZE': 'SPARK',
  'SILVER': 'STAR',
  'GOLD': 'CONSTELLATION',
  'DIAMOND': 'GALAXY',
};

/// The level's known code: an old default code reads as its new one; any
/// other code (a level the OWNER added) as itself.
String ambassadorLevelCode(String code) =>
    ambassadorLegacyLevelCodes[code] ?? code;

/// The level's name (§10.179.9): «شرارة / نجم / كوكبة / مجرّة» for the four
/// default codes (and their old codes); any other code shows as it is.
String ambassadorLevelName(AppLocalizations l10n, String code) =>
    l10n.ambLevelName(ambassadorLevelCode(code));

/// The owner's art for a default level (`assets/ambassadors/`,
/// PROVENANCE.md); null for a level the OWNER added.
String? ambassadorLevelArt(String code) => switch (ambassadorLevelCode(code)) {
  'SPARK' => 'assets/ambassadors/spark.webp',
  'STAR' => 'assets/ambassadors/star.webp',
  'CONSTELLATION' => 'assets/ambassadors/constellation.webp',
  'GALAXY' => 'assets/ambassadors/galaxy.webp',
  _ => null,
};

/// The level's colours (D390, §10.179.9): two stops of the pill's gradient
/// and the text on it, matched to each icon — Spark orange, Star gold,
/// Constellation purple, Galaxy cosmic blue. Any other code (the OWNER may
/// add levels) uses the brand's.
({Color from, Color to, Color ink}) ambassadorLevelColors(
  String code,
  KPalette p,
) => switch (ambassadorLevelCode(code)) {
  'SPARK' => (
    from: const Color(0xFFFFA24C),
    to: const Color(0xFFD9480F),
    ink: const Color(0xFFFFFFFF),
  ),
  'STAR' => (
    from: const Color(0xFFFFE27A),
    to: const Color(0xFFE0A100),
    ink: const Color(0xFF3B2A00),
  ),
  'CONSTELLATION' => (
    from: const Color(0xFFB98CFF),
    to: const Color(0xFF6D28D9),
    ink: const Color(0xFFFFFFFF),
  ),
  'GALAXY' => (
    from: const Color(0xFF5EB6FF),
    to: const Color(0xFF3730A3),
    ink: const Color(0xFFFFFFFF),
  ),
  _ => (from: p.primary, to: p.primary, ink: p.onPrimary),
};

/// The D389 explainer's text for an ambassador badge («سفير Kabso — المستوى
/// كوكبة», CONVENTIONS §10.178.2 / §10.179.9).
String ambassadorBadgeExplainer(AppLocalizations l10n, String level) =>
    l10n.ambBadgeExplainer(ambassadorLevelName(l10n, level));

/// v1.141-social (D390, §10.179.9): the exclusive «سفير Kabso» badge — the
/// level's medal (the owner's art) at full height, overlapping the start of
/// a pill in the level's colours with the level's name. Its spoken label is
/// «سفير Kabso · {المستوى}». D389: a tap explains it ([KBadgeExplainer],
/// [ambassadorBadgeExplainer]). A level the OWNER added has no art: a crest
/// in a circle stands in.
class AmbassadorBadge extends StatelessWidget {
  const new({
    required this.level,
    super.key,
    this.large = false,
    this.height,
    this.explain = true,
  });

  final String level;

  /// The dashboard's hero size (else the inline size).
  final bool large;

  /// A fixed height (the profile's and person card's badge rows).
  final double? height;

  /// D389: a tap shows what the badge is (false: only a picture).
  final bool explain;

  static const badgeKey = Key('ambassador.badge');

  /// The medal picture (absent for a level without art).
  static const artKey = Key('ambassador.badge.art');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = ambassadorLevelColors(level, context.palette);
    final name = ambassadorLevelName(l10n, level);
    final art = ambassadorLevelArt(level);
    final h = height ?? (large ? 32.0 : 22.0);
    final pillH = (h * 0.8).roundToDouble();
    final medal = art == null
        ? Container(
            width: h,
            height: h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [c.from, c.to]),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: h - 8,
              color: c.ink,
            ),
          )
        : Image.asset(
            art,
            key: artKey,
            width: h,
            height: h,
            excludeFromSemantics: true,
          );
    return KBadgeExplainer(
      message: ambassadorBadgeExplainer(l10n, level),
      enabled: explain,
      child: Semantics(
        label: l10n.ambBadgeLabel(name),
        excludeSemantics: true,
        child: SizedBox(
          key: badgeKey,
          height: h,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(start: h / 2),
                child: Container(
                  height: pillH,
                  padding: EdgeInsetsDirectional.only(
                    start: h / 2 + (large ? 6 : 4),
                    end: large ? KSpacing.md : 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(pillH),
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [c.from, c.to],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.to.withValues(alpha: 0.3),
                        blurRadius: large ? 8 : 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  // A row, not an alignment: the pill hugs the name (and
                  // ellipsises it when the badge is given less room).
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
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
                      ),
                    ],
                  ),
                ),
              ),
              medal,
            ],
          ),
        ),
      ),
    );
  }
}
