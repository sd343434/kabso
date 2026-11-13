import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.95-social (D301, §10.112.2): the label «رسمي» of the app owner's
/// official announcement — Kabso red with a gold edge, so it never reads as
/// the Kabso Team's green «إعلان رسمي — فريق كابسو» (D283).
class OfficialPostLabel extends StatelessWidget {
  const new({super.key});

  static const labelKey = Key('post.official');

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.ownerOfficialLabel;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: labelKey,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [KBrandColors.red400, KBrandColors.red600],
            ),
            borderRadius: BorderRadius.circular(KRadius.pill),
            border: Border.all(color: KBrandColors.gold),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.sm,
              vertical: KSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: KBrandColors.gold,
                ),
                const SizedBox(width: KSpacing.xxs),
                Text(
                  label,
                  maxLines: 1,
                  style: context.textStyles.caption.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
