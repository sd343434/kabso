import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart' show Color;

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

  /// QA-009: below this screen width the viewer strip drops its avatars
  /// (count chip only) so the host name keeps ≥ ~8 visible characters.
  static const double viewerAvatarsMinScreenWidth = 430;

  /// Disabled content opacity (§9.8 / §9.5: 38 %).
  static const double disabledOpacity = 0.38;

  // KL-033 Home feed / Live hub (HOME_LIVE_LAYOUT_DECISIONS §5). Held here
  // instead of the token contract until the owner approves the redesign
  // (D36: proposals T-1–T-5 are not contract changes in this sprint).

  /// T-3 proposal: header bar with the primary tabs and search.
  static const double topBarHeight = KSizes.minTouchTarget;

  /// T-2 proposal: primary tabs clamp text scaling so the 48 dp header
  /// keeps its height (the screen-reader label is never clamped).
  static const double topBarMaxTextScale = 1.3;

  /// HL-H2 short indicator under the selected primary tab.
  static const double tabIndicatorWidth = KSpacing.lg;
  static const double tabIndicatorHeight = strokeLarge;

  /// HL-H3 filter chip: 32 dp visual inside a 48 dp hit area.
  static const double chipHeight = KSpacing.xxl;

  /// HL-H4 live grid: side padding and column/row gap.
  static const double liveGridPadding = KSpacing.sm;
  static const double liveGridGap = KSpacing.xs;

  /// HL-H6 loading: skeleton cards (3 rows of 2).
  static const int liveGridSkeletonCount = 6;

  /// HL-H6 loading skeletons appear only after this delay (no flash).
  static const Duration loadingRevealDelay = Duration(milliseconds: 300);

  /// §2 bottom nav: active-destination dot above the icon.
  static const double navDotSize = KSpacing.xs;

  /// KL-047: vertical placement of a feed region's state block in the space
  /// under the header (`Alignment.y`: −1 top, 0 centre). Slightly above the
  /// centre so the block reads as composed, not dropped into a void.
  static const double regionStateAlignmentY = -0.25;

  /// VG-03 compact empty/error state icon (no circle container).
  static const double compactStateIcon = KSpacing.xxxl;

  /// VG-44 card press feedback.
  static const double cardPressedScale = 0.98;

  /// T-5 proposal alias: feed post media without its own aspect ratio.
  static const double feedMediaAspect = KSizes.liveCardAspect;

  // KL-034 live room (HOME_LIVE_LAYOUT_DECISIONS §3, §5 KMetrics list).
  // Kabso values; none is taken from a reference image.

  /// HL-L2 host pill visual height (grows with text scale).
  static const double hostPillHeight = 40;

  /// HL-L2 follow chip visual height inside its 48 dp hit area.
  static const double followChipHeight = 28;

  /// HL-L2: after following, the check stays this long, then fades out.
  static const Duration followConfirmDuration = Duration(seconds: 1);

  /// HL-L6/L7 round room buttons (gift, share): visual inside 48 dp.
  static const double roomIconVisual = 40;

  /// HL-L3 close button visual inside its 48 dp hit area, and its × icon.
  static const double closeVisual = KSpacing.xxl;
  static const double closeIcon = 20;

  /// HL-L4 room info chips (title, category).
  static const double roomInfoChipHeight = 28;

  /// HL-L5 chat height cap as a fraction of the screen height.
  static const double chatMaxHeightFactor = 0.30;

  /// HL-L1 / VG-26 legibility gradients (T-4 proposal): black 0→45 % over
  /// 120 dp at the top, 0→55 % over 280 dp at the bottom.
  static const double legibilityTopHeight = 120;
  static const double legibilityBottomHeight = 280;
  static const Color legibilityTop = Color(0x73000000);
  static const Color legibilityBottom = Color(0x8C000000);
  static const Color legibilityClear = Color(0x00000000);

  /// HL-L10 ended overlay: `background` at 90 %.
  static const double endedOverlayOpacity = 0.9;

  /// HL-L10 reconnecting: the last frame is dimmed by 30 %.
  static const Color reconnectingDim = Color(0x4D000000);

  /// HL-L6 gift sheet: max height as a fraction of the screen (the sheet
  /// sizes to its content, about 45 % with two rows).
  static const double giftSheetMaxHeightFactor = 0.6;

  /// Room sheets never dim the stream (HL-L6, VG-33, VG-43).
  static const Color roomSheetBarrier = Color(0x00000000);

  /// HL-L8 PK pane width / height (T-5 proposal alias of the card aspect).
  static const double pkPaneAspect = KSizes.liveCardAspect;

  /// HL-L8 Kabso-original VS mark on the pane seam.
  static const double pkVsMark = KSpacing.xxl;

  /// HL-L8 supporter avatars under each pane.
  static const double pkSupporterAvatar = KSpacing.xl;

  /// HL-L8 per-pane result overlay stays this long (VG-39).
  static const Duration pkResultDuration = Duration(seconds: 3);

  /// Multi-guest seat grid: columns and the seat aspect (T-5).
  static const int guestSeatColumns = 3;
  static const double guestSeatAspect = KSizes.liveCardAspect;
}
