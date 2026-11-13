// D299g / D299h (owner: «اجعل آيدي الموظفين مميزاً من نوع ذهبي», then «لا،
// هكذا الآيدي غير مميز مثل آيدي المميز الذهبي بأيقونة»): the Kabso Team's
// official staff ID (D283c) is drawn exactly like a GOLD premium username
// (D146, [KSpecialUsername]; since D299j the owner's gold art: the gold
// medal over the purple-glass plate with its amethysts, the light sweep off
// in tests and with reduced motion). It shows the bare ID, «Kabso01»
// — no «@» and no «ID:», as a premium name (D158) — and is still read as
// the official staff ID (D283c's hint), never as a paid name.

import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/design_system/components/k_special_username.dart';
import 'package:material_ui/material_ui.dart';

/// A staff ID as the gold special-ID badge. Shrinks (never overflows) in a
/// narrow place; [height] is the pill's (the medal ≈ 1.4 ×).
class KStaffIdText extends StatelessWidget {
  const new(
    this.staffId, {
    super.key,
    this.height = normal,
    this.semanticHint,
    this.alignment = AlignmentDirectional.centerStart,
    this.effects = KSpecialIdEffects.sweepOnly,
  });

  final String staffId;
  final double height;

  /// Read after the ID (the D283c «official staff ID» hint).
  final String? semanticHint;
  final AlignmentGeometry alignment;

  /// D299l: the gold tier's full motion where the ID is prominent (the
  /// profile bar, the Me tab, the person card); only the sweep elsewhere.
  final KSpecialIdEffects effects;

  /// The tier whose pill and medal a staff ID wears.
  static const PremiumTier tier = PremiumTier.gold;

  /// List rows: the premium badge's list size.
  static const double list = 18;

  /// The Me tab and the person card.
  static const double normal = 22;

  /// The profile's top bar (as the premium badge there).
  static const double bar = 24;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: KSpecialUsername(
      username: staffId,
      tier: tier,
      height: height,
      semanticHint: semanticHint,
      effects: effects,
    ),
  );
}
