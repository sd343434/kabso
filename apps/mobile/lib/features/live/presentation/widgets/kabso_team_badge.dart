import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D260 (owner: staff who watch a live are shown, so the host knows the live
/// is watched): the Kabso Team's colours — a calm blue, unlike any level,
/// VIP or agent badge.
abstract final class KabsoTeamColors {
  static const start = Color(0xFF0EA5E9);
  static const end = Color(0xFF2563EB);
  static const gradient = LinearGradient(colors: [start, end]);
}

/// D282 (owner: «اجعلها شارة فريق كابسو بحيث سوف تضع الاسم بالعربي لمن هاتفه
/// عربي وانجليزي لمن هاتفه انجليزي»): THE «فريق كابسو» badge — the owner's
/// crest ([asset]; D282c: the red-and-gold crest with Kabi in a headset).
/// D389 (owner: «فريق كابسو يأخذون شارة لكن الشارة لها شريط ازله»): the
/// long banner that carried the team's name is gone — the badge is the crest
/// alone (with the small ribbon scroll under it, part of the emblem), drawn
/// [height] tall at the crest's own [aspectRatio]. The team's name is no
/// longer written on it: it is the badge's spoken label («فريق كابسو» /
/// "Kabso Team") and, on a tap, the explainer bubble ([KBadgeExplainer])
/// says what it is. Shown wherever the team is: before a staff line's name
/// in every chat mode (D269's team tag), the viewer list's staff group
/// (D260), the person card and profile of a staff account, the staff tools
/// sheet and the shift page (D273).
///
/// Right-to-left: the art is NOT mirrored (a mirrored crown and laurels
/// would read as a different emblem).
class KabsoTeamBadge extends StatelessWidget {
  const new({super.key, this.height = 18, this.explain = true});

  static const badgeKey = Key('live.kabsoTeam.badge');

  /// The owner's crest (assets/staff/PROVENANCE.md), trimmed to its bounds.
  static const asset = 'assets/staff/kabso_team_badge.png';

  /// The crest's width ÷ height (398 × 328 px).
  static const double aspectRatio = 398 / 328;

  /// D282b: in a chat line the crest is taller than the line's other
  /// emblems so it reads — 24 pt in the boxed, inline and VIP rows (D389:
  /// 29 pt wide now, was 53 with the banner) …
  static const double chatHeight = 24;

  /// … and 22 pt on the host's compact flat line.
  static const double flatChatHeight = 22;

  /// D292 / D299i set 44 pt beside the name on the Me hub so the banner's
  /// name read. D389: with no name to read, 36 pt (44 wide, was 97) — still
  /// the largest emblem of the row, never squeezed (in a tight row it wraps
  /// to its own line).
  static const double profileHeight = 36;

  /// D299i: the live person card, after the name (D389: 28, was 32).
  static const double cardHeight = 28;

  /// D299i: before «إعلان رسمي — فريق كابسو» in the composer (D389: 24,
  /// was 28 — the label beside it says the team's name).
  static const double announcementHeight = 24;

  final double height;

  /// D389: a tap shows what the badge is (false: a badge drawn as a
  /// picture only).
  final bool explain;

  double get width => height * aspectRatio;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return KBadgeExplainer(
      message: l10n.badgeExplainKabsoTeam,
      enabled: explain,
      child: Semantics(
        label: l10n.liveKabsoTeam,
        container: true,
        excludeSemantics: true,
        child: SizedBox(
          key: badgeKey,
          width: width,
          height: height,
          child: Image.asset(
            asset,
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// D260: the team's shield by the top viewers while staff watch the live —
/// never a face among the supporters, never ranked, not counted.
class KabsoTeamShield extends StatelessWidget {
  const new({required this.size, super.key});

  static const shieldKey = Key('live.kabsoTeam.shield');

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.liveKabsoTeamHere,
    child: Container(
      key: shieldKey,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: KabsoTeamColors.gradient,
        border: Border.all(color: const Color(0xCCFFFFFF)),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.verified_user_rounded,
        size: size * 0.6,
        color: const Color(0xFFFFFFFF),
      ),
    ),
  );
}

/// D260: what a tap on a staff entry shows — who the Kabso Team is (no
/// person card, no actions).
Future<void> showKabsoTeamInfo(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialog) => AlertDialog(
    icon: const KabsoTeamShield(size: 44),
    title: Text(dialog.l10n.liveKabsoTeamInfoTitle),
    content: Text(dialog.l10n.liveKabsoTeamInfo, textAlign: TextAlign.center),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialog).pop(),
        child: Text(MaterialLocalizations.of(dialog).okButtonLabel),
      ),
    ],
  ),
);
