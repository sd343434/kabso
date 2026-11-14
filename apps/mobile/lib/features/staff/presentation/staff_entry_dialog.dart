import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.68-live (D273; owner «ويمكن كما في لوحة مراقبة خفية»): the first live a
/// staff member enters in this app run asks how — «دخول ظاهر (فريق كابسو)»
/// or, with `lives.watch.hidden` (OWNER, MODERATION), «مراقبة خفية». The
/// choice is remembered for the session; the staff sheet switches it.
Future<StaffVisibility?> showStaffEntryChoice(
  BuildContext context, {
  required bool canHidden,
}) => showDialog<StaffVisibility>(
  context: context,
  builder: (_) => StaffEntryDialog(canHidden: canHidden),
);

class StaffEntryDialog extends StatelessWidget {
  const new({required this.canHidden, super.key});

  static Key optionKey(StaffVisibility v) => Key('staff.enter.${v.name}');

  final bool canHidden;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    Widget option(
      StaffVisibility v,
      IconData icon,
      String title,
      String hint,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Material(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: ListTile(
          key: optionKey(v),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KRadius.md),
          ),
          leading: Icon(icon, color: KabsoTeamColors.end),
          title: Text(title, style: context.textStyles.bodyStrong),
          subtitle: Text(hint),
          onTap: () => Navigator.of(context).pop(v),
        ),
      ),
    );
    return AlertDialog(
      icon: const KabsoTeamShield(size: 44),
      title: Text(l10n.staffEnterTitle, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            StaffVisibility.visible,
            Icons.verified_user_rounded,
            l10n.staffEnterVisible,
            l10n.staffEnterVisibleHint,
          ),
          if (canHidden)
            option(
              StaffVisibility.hidden,
              Icons.visibility_off_rounded,
              l10n.staffEnterHidden,
              l10n.staffEnterHiddenHint,
            ),
        ],
      ),
    );
  }
}
