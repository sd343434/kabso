import 'package:kabso_live/design_system/tokens/tokens.dart';

/// Component dimensions fixed by DESIGN_SYSTEM §9 (and REFERENCE_INVENTORY
/// §7) that have no entry in `design-tokens.json` v1.1.
///
/// Values equal to an existing token are aliases of that token. The rest
/// are spec literals, kept here in one place (never inline in widgets) and
/// proposed to the CTO for promotion to tokens — see the KL-022 report.
abstract final class KMetrics {
  // Strokes ---------------------------------------------------------------

  /// Decorative 1 dp outlines (tab baseline, chips).
  static const double hairline = 1;

  /// §9.4 story-seen ring, §9.11 selected gift cell outline. Spec literal.
  static const double thinStroke = 1.5;

  /// §9.4 ring stroke for `sm`/`md`; §9.8 tab indicator; §9.10 card accent.
  static const double stroke = KSpacing.xxs;

  /// §9.4 ring stroke for `lg` and `story`. Spec literal.
  static const double strokeLarge = 3;

  // Icons -----------------------------------------------------------------

  static const double iconXs = KSpacing.md;
  static const double iconSm = KSpacing.lg;
  static const double iconMd = KSpacing.xl;
  static const double iconLg = KSpacing.xxl;

  // Badges (§9.5) ---------------------------------------------------------

  /// Height of `live`, `pk` and `liveWithViewers` badges. Spec literal.
  static const double badgeHeight = 20;

  // Avatar rings (§9.4) ---------------------------------------------------

  static const double ringGap = KSpacing.xxs;

  /// `lg` avatar ring gap. Spec literal (same as [strokeLarge]).
  static const double ringGapLarge = strokeLarge;

  /// Image inside the 68 dp story ring: 68 − 2 × (3 + 2). Spec literal.
  static const double storyImage = 58;

  // Tabs (§9.8) -----------------------------------------------------------

  /// Minimum tab width. Spec literal.
  static const double tabMinWidth = 72;

  // Bottom sheet (§9.11) --------------------------------------------------

  static const double sheetHandleWidth = KSpacing.xxl;
  static const double sheetHandleHeight = KSpacing.xs;

  /// Max sheet height as a fraction of the screen.
  static const double sheetMaxHeightFactor = 0.9;

  /// Gift artwork in a grid cell.
  static const double giftArt = KSizes.avatarMd;

  // Live room (REFERENCE_INVENTORY §4, G-07/G-09/G-12) ----------------------

  /// Chat overlay: lines visible before older lines fade/scroll away.
  static const int chatMaxVisibleLines = 6;

  /// Chat overlay max width as a fraction of the room width (keeps the
  /// end side free for the action column).
  static const double chatWidthFactor = 0.75;

  /// Fraction of the chat overlay height used by the top fade.
  static const double chatFadeFraction = 0.25;

  /// PK bar height: fits the ≥ 20 sp / 700 score text (contrast rule).
  static const double pkBarHeight = KSpacing.xl;

  /// Minimum PK score text size so white on pk fills passes 3:1 as large text.
  static const double pkScoreMinFontSize = 20;

  /// Line height of the PK score text (20 × 1.2 = the 24 dp bar).
  static const double pkScoreLineHeight = 1.2;

  /// Smallest share of the PK bar either side keeps so its score is legible.
  static const double pkMinShare = 0.2;

  /// The PK timer is emphasised during the final seconds.
  static const Duration pkUrgentThreshold = Duration(seconds: 10);

  /// Live cover card: share of the card height covered by the bottom scrim.
  static const double cardScrimFraction = 0.5;

  /// Overlay surfaces (chat, room chrome) clamp text scaling here
  /// (REFERENCE_INVENTORY §6.1).
  static const double overlayMaxTextScale = 1.3;

  /// Gift grid cell width / height (art, name and price stacked).
  static const double giftCellAspect = 0.75;

  /// Peak scale of the ×N combo bump (`motion.giftComboBumpMs`).
  static const double giftComboBumpScale = 1.3;

  /// Viewer avatars shown in the room's viewer strip before the count.
  static const int viewerStripMax = 3;

  /// Disabled content opacity (§9.8 / §9.5: 38 %).
  static const double disabledOpacity = 0.38;
}
