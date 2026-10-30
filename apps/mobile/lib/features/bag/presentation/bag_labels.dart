import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/l10n/l10n.dart';

/// One day: the unit of a partial send (D171, CONVENTIONS §10.45).
const bagDay = Duration(days: 1);

/// The tab / heading of a category's wire value; a category this app does
/// not know yet (a newer server) is «other items».
String bagCategoryTitle(AppLocalizations l10n, String wire) =>
    switch (BagCategory.fromWire(wire)) {
      BagCategory.profileCard => l10n.bagCategoryProfileCard,
      BagCategory.avatarFrame => l10n.bagCategoryAvatarFrame,
      null => l10n.bagCategoryOther,
    };

/// [left] in words: «6 أيام 4 ساعات», «5 ساعات», «12 دقيقة».
String bagDurationText(AppLocalizations l10n, Duration left) {
  if (left.inHours < 1) {
    final minutes = left.inSeconds <= 0 ? 0 : (left.inSeconds + 59) ~/ 60;
    return l10n.bagMinutes(minutes < 1 ? 1 : minutes);
  }
  final days = left.inDays;
  final hours = left.inHours % 24;
  if (days == 0) return l10n.bagHours(hours);
  if (hours == 0) return l10n.bagDays(days);
  return l10n.bagDurationPair(l10n.bagDays(days), l10n.bagHours(hours));
}

/// The item's time line (D171, owner): «دائم» for a permanent item,
/// «ينتهي اليوم» when it ends later on the local day (and more than an
/// hour from now), else «متبقٍ …».
String bagTimeLeft(AppLocalizations l10n, DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return l10n.bagPermanent;
  final left = expiresAt.difference(now);
  final end = expiresAt.toLocal();
  final today = now.toLocal();
  final sameDay =
      end.year == today.year &&
      end.month == today.month &&
      end.day == today.day;
  if (left.inHours >= 1 && sameDay) return l10n.bagEndsToday;
  return l10n.bagRemaining(bagDurationText(l10n, left));
}

/// Who the item came from (D171, owner): «هدية من Kabso», «هدية من @user»,
/// a level reward, bought; null for a source this app does not word.
String? bagSourceLine(AppLocalizations l10n, BagItem item) =>
    switch (item.source) {
      BagSource.freeSignup ||
      BagSource.backfill ||
      BagSource.admin => l10n.bagFromKabso,
      BagSource.gift => switch (item.giftedBy) {
        final u? => l10n.bagFromUser(
          KHandle.text(l10n, u.username, premiumTier: u.premiumTier),
        ),
        null => l10n.bagFromSomeone,
      },
      BagSource.levelReward => l10n.bagFromLevel,
      BagSource.hostActive => l10n.bagFromHostActive,
      BagSource.purchase => l10n.bagFromPurchase,
      _ => null,
    };

/// Why «إرسال» is off for [item], or null when it can be sent.
String? bagNoSendReason(AppLocalizations l10n, BagItem item) {
  if (item.transferable) return null;
  return switch (item.source) {
    BagSource.freeSignup || BagSource.backfill => l10n.bagNoSendFree,
    BagSource.levelReward => l10n.bagNoSendLevel,
    BagSource.hostActive => l10n.bagNoSendHostActive,
    _ => l10n.bagNoSendOther,
  };
}

/// The whole days that may be sent out of [left] (each strictly less than
/// it, CONVENTIONS §10.45): a few presets plus the most whole days.
List<int> bagSendDayOptions(Duration left) {
  var max = left.inDays;
  if (max > 0 && left == bagDay * max) max -= 1;
  if (max < 1) return const [];
  return {
    for (final d in const [1, 3, 7, 15, 30])
      if (d <= max) d,
    max,
  }.toList()..sort();
}
