import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';
import 'package:kabso_live/l10n/l10n.dart';

/// The tier's name («ماسي», "Diamond").
String premiumTierName(AppLocalizations l10n, PremiumTier tier) =>
    switch (tier) {
      PremiumTier.legend => l10n.premiumTierLegend,
      PremiumTier.ruby => l10n.premiumTierRuby,
      PremiumTier.gold => l10n.premiumTierGold,
      PremiumTier.silver => l10n.premiumTierSilver,
    };

/// What names the tier holds («١–٣ أحرف»).
String premiumTierRule(AppLocalizations l10n, PremiumTier tier) =>
    switch (tier) {
      PremiumTier.legend => l10n.premiumTierLegendRule,
      PremiumTier.ruby => l10n.premiumTierRubyRule,
      PremiumTier.gold => l10n.premiumTierGoldRule,
      PremiumTier.silver => l10n.premiumTierSilverRule,
    };

/// "5000 coins / 30 days".
String premiumPriceLabel(AppLocalizations l10n, int coins, int days) =>
    l10n.premiumPricePerPeriod(KFormat.grouped(coins), days);

/// One line saying what [status] means for the person.
String premiumStateLine(AppLocalizations l10n, PremiumNameStatus status) =>
    switch (status.state) {
      PremiumNameState.available => l10n.premiumStateAvailable,
      PremiumNameState.notForSale => l10n.premiumStateNotForSale,
      PremiumNameState.taken => l10n.premiumStateTaken,
      PremiumNameState.held => l10n.premiumStateHeld,
      PremiumNameState.yours => l10n.premiumStateYours,
      PremiumNameState.yoursGrace => l10n.premiumStateYoursGrace,
      PremiumNameState.reserved => l10n.premiumStateReserved,
      PremiumNameState.regular => l10n.premiumStateRegular,
      PremiumNameState.invalid => l10n.premiumStateInvalid,
      PremiumNameState.unknown => l10n.premiumStateTaken,
    };

/// "12 days 4 h" / "3 hours 20 min" / "less than a minute": [left].
String premiumTimeLeft(AppLocalizations l10n, Duration left) {
  if (left.inMinutes < 1) return l10n.premiumLeftUnderMinute;
  if (left.inHours < 1) return l10n.premiumLeftMinutes(left.inMinutes);
  if (left.inDays < 1) {
    return l10n.premiumLeftHours(left.inHours, left.inMinutes % 60);
  }
  return l10n.premiumLeftDays(left.inDays, left.inHours % 24);
}
