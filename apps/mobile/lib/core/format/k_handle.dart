import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/l10n/l10n.dart';

/// D158 (owner: «عدل يوزر مميز ولا تضع قبله @»): the one place that turns a
/// username into the handle people see. A regular username shows as
/// `@sara_2026`; a premium username (D146, the server sends its
/// `premiumTier`) shows bare, without «@» (`1`, `7777`). Mentions people
/// type (`@name ` in a composer) are syntax, not display, and keep «@».
abstract final class KHandle {
  /// `@sara_2026`, or `1` for a premium username. Plain text with no
  /// direction marks: for a widget that is already left to right, a pill,
  /// a copied handle or a share text.
  static String plain(String username, {PremiumTier? premiumTier}) =>
      premiumTier == null ? '@$username' : username;

  /// [plain] in a left-to-right isolate: for a `Text` that follows the
  /// reading direction (a settings row in Arabic).
  static String isolated(String username, {PremiumTier? premiumTier}) =>
      ltr(plain(username, premiumTier: premiumTier));

  /// The handle for running text in either language: a regular username
  /// keeps the localized `profileUsername` (`@…`, kept left to right in
  /// Arabic); a premium one is wrapped in a left-to-right isolate so digits
  /// and `_` are never reordered inside Arabic text.
  static String text(
    AppLocalizations l10n,
    String username, {
    PremiumTier? premiumTier,
  }) => premiumTier == null ? l10n.profileUsername(username) : ltr(username);

  /// [value] in a left-to-right isolate (U+2066 … U+2069).
  static String ltr(String value) => '\u2066$value\u2069';
}
