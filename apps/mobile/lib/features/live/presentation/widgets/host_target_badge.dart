import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart'
    show KWizardHatIcon;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D281: a smart target's mark. D281b (owner): a target about ONE gift
/// («استقبل 100 هدية من المحارب», a combo of it; either tab) shows that gift's
/// CURRENT hosted picture (`imageUrl`, the catalogue's art); every other
/// target shows its tab's badge — the gift box
/// (`assets/host_targets/gifts_target.png`) on «الهدايا», the lucky badge
/// (`lucky_target.png`) on «هدايا الحظ».
class KDailyTargetBadge extends StatelessWidget {
  const new(this.target, {super.key, this.size = 16});

  final HostDailyTarget target;
  final double size;

  static Key giftKeyOf(TargetLevel level) =>
      Key('target.daily.gift.${level.name}');

  @override
  Widget build(BuildContext context) {
    final gift = target.gift;
    if (gift != null) {
      return KGiftImage(
        gift.assetKey,
        key: giftKeyOf(target.level),
        imageUrl: gift.imageUrl,
        size: size,
      );
    }
    return KHostTargetBadge(
      target.lucky ? HostTargetKind.lucky : HostTargetKind.gifts,
      size: size,
    );
  }
}

/// D281: «سهل / متوسط / صعب».
String targetLevelLabel(AppLocalizations l10n, TargetLevel level) =>
    switch (level) {
      TargetLevel.easy => l10n.liveTargetLevelEasy,
      TargetLevel.medium => l10n.liveTargetLevelMedium,
      TargetLevel.hard => l10n.liveTargetLevelHard,
    };

/// D281: each level's colour (green, amber, Kabso red).
Color targetLevelColor(TargetLevel level) => switch (level) {
  TargetLevel.easy => const Color(0xFF34C759),
  TargetLevel.medium => const Color(0xFFFFB020),
  TargetLevel.hard => KBrandColors.red500,
};

/// The host's two daily targets «تارجت» (D199; D277: both in cherries).
enum HostTargetKind {
  /// «هدف الهدايا»: the cherries of gifts outside the lucky category.
  gifts('assets/host_targets/gifts_target.png'),

  /// «هدف هدايا الحظ»: the cherries of lucky gifts.
  lucky('assets/host_targets/lucky_target.png');

  new(this.asset);

  /// The badge's art. D277 (owner: «واستبدل الشارة بشارة اخرى ساقوم
  /// بارفاقها»): a fixed slot — replacing the file swaps the badge on the
  /// chip and the sheet with no code change (assets/host_targets/PROVENANCE.md).
  final String asset;
}

/// D277: a target's badge on the «تارجت» chip and in its sheet, drawn from
/// the target's asset slot ([HostTargetKind.asset]). Until the owner's art
/// arrives the slots hold stand-ins: the Kabso cherry (gifts) and the D199
/// wizard hat (lucky). A missing or broken file falls back to the same art
/// drawn in code, so the chip never loses its mark.
class KHostTargetBadge extends StatelessWidget {
  const new(this.kind, {super.key, this.size = 16});

  final HostTargetKind kind;
  final double size;

  static Key keyOf(HostTargetKind kind) => Key('target.badge.${kind.name}');

  @override
  Widget build(BuildContext context) => Image.asset(
    kind.asset,
    key: keyOf(kind),
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => switch (kind) {
      HostTargetKind.gifts => KCherryIcon(size: size),
      HostTargetKind.lucky => KWizardHatIcon(size: size),
    },
  );
}
