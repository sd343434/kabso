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

/// D260: the «فريق كابسو» / «Kabso Team» pill after a staff member's name in
/// the viewer list.
class KabsoTeamBadge extends StatelessWidget {
  const new({super.key, this.height = 18});

  static const badgeKey = Key('live.kabsoTeam.badge');

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    key: badgeKey,
    height: height,
    padding: EdgeInsets.symmetric(horizontal: height * 0.4),
    decoration: BoxDecoration(
      gradient: KabsoTeamColors.gradient,
      borderRadius: BorderRadius.circular(height / 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_user_rounded,
          size: height * 0.66,
          color: const Color(0xFFFFFFFF),
        ),
        SizedBox(width: height * 0.18),
        Text(
          context.l10n.liveKabsoTeam,
          maxLines: 1,
          style: context.textStyles.caption.copyWith(
            fontSize: height * 0.58,
            height: 1,
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
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
