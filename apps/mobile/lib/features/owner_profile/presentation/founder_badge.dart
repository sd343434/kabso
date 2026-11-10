// D357 (owner, 2026-11-10: «شارته في المنتصف لكن بلون احمر وبداخلها اشارة
// مثلث كاليوتيوب مفرغة»): the founder's badge on his page — an ORIGINAL
// Kabso mark ([AppIcons.founderBadge]): a red rounded shield holding an
// outlined (stroke-only) play triangle, the play of Kabso's own mascot. Not
// YouTube's logo (a wide red rounded rectangle with a solid white
// triangle): a taller shield, the brand reds, the triangle only drawn.
// Replaces the blue verification seal on the founder's page only.

import 'package:flutter_svg/flutter_svg.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The founder's red badge, read as «مؤسس Kabso Live» / "Kabso Live
/// founder" (one label; a tooltip on long press).
class FounderBadge extends StatelessWidget {
  const new({super.key, this.height = defaultHeight});

  /// The badge's height (its width is [aspect] of it).
  final double height;

  /// Under the name on the founder's page (E: the name's cap height × 1.6).
  static const double defaultHeight = 30;

  /// The art's width ÷ height (24 × 26 units).
  static const double aspect = 24 / 26;

  static const badgeKey = Key('founder.badge');

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.founderBadgeLabel;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        key: badgeKey,
        label: label,
        image: true,
        container: true,
        child: SvgPicture.asset(
          AppIcons.founderBadge,
          height: height,
          width: height * aspect,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
