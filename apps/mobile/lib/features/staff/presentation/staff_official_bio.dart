import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The official card's colours: the team art's deep red and gold.
abstract final class StaffBioColors {
  static const gold = Color(0xFFE9C46A);
  static const goldDeep = Color(0xFFD4A537);
  static const ink = Color(0xFFFFF6E5);

  /// Light mode: a richer red so the card stands out on a white page.
  static const lightGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF9B1626), Color(0xFF5A0D17), Color(0xFF2A0A10)],
    stops: [0, 0.55, 1],
  );

  /// Dark mode: deeper and quieter, fading into the dark page.
  static const darkGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF6E0F1B), Color(0xFF3A0A12), Color(0xFF160709)],
    stops: [0, 0.55, 1],
  );
}

/// D283b (owner: «اجعل بايو ملفت واجمل لانه هذه شركة بالعربي والانجليزي»):
/// a Kabso Team account's bio is the company's fixed official text in the
/// viewer's language — never the typed one — on a red-to-dark card with a
/// thin gold border, a shield, «الحساب الرسمي» / "Official account" and the
/// staff member's region line in its header.
class StaffOfficialBio extends StatelessWidget {
  const new({required this.staff, super.key});

  final KabsoStaffIdentity staff;

  static const cardKey = Key('staff.officialBio');
  static const titleKey = Key('staff.officialBio.title');
  static const textKey = Key('staff.officialBio.text');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      key: cardKey,
      decoration: BoxDecoration(
        gradient: dark
            ? StaffBioColors.darkGradient
            : StaffBioColors.lightGradient,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(
          color: (dark ? StaffBioColors.goldDeep : StaffBioColors.gold)
              .withValues(alpha: 0.85),
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF5A0D17).withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Stack(
          children: [
            // A faint shield watermark at the reading end.
            PositionedDirectional(
              end: -10,
              bottom: -14,
              child: ExcludeSemantics(
                child: Icon(
                  Icons.shield_rounded,
                  size: 84,
                  color: StaffBioColors.gold.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.md,
                KSpacing.sm + 2,
                KSpacing.md,
                KSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: StaffBioColors.gold,
                        ),
                      ),
                      const SizedBox(width: KSpacing.xs + 2),
                      Expanded(
                        child: Text.rich(
                          key: titleKey,
                          TextSpan(
                            children: [
                              TextSpan(
                                text: l10n.staffOfficialBioTitle,
                                style: const TextStyle(
                                  color: StaffBioColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: '  ·  ${staff.line(l10n)}',
                                style: TextStyle(
                                  color: StaffBioColors.ink.withValues(
                                    alpha: 0.78,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          style: t.body.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xs + 2),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [
                          StaffBioColors.gold.withValues(alpha: 0.55),
                          StaffBioColors.gold.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: KSpacing.xs + 2),
                  Text(
                    l10n.staffOfficialBio,
                    key: textKey,
                    style: t.body.copyWith(
                      color: StaffBioColors.ink,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
