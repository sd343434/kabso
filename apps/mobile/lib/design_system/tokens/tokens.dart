// Hand-written 1:1 from docs/contracts/design-tokens.json (v1.1).
// Do not change values here without a contract change to that file.

import 'package:material_ui/material_ui.dart';

/// `color.brand`
abstract final class KBrandColors {
  static const red500 = Color(0xFFE50914);
  static const red400 = Color(0xFFFF3B47);
  static const red600 = Color(0xFFB80710);
  static const red700 = Color(0xFF8A050C);
  static const gradientLive = [
    Color(0xFFFF3B47),
    Color(0xFFE50914),
    Color(0xFF8A050C),
  ];
  static const gold = Color(0xFFF5C451);
}

/// `color.live`
abstract final class KLiveColors {
  static const badge = Color(0xFFE50914);
  static const pkLeft = Color(0xFFFF3B6B);
  static const pkRight = Color(0xFF3B8BFF);

  /// v1.1: behind live chat lines (60 % black; white text stays ≥ 5.74:1
  /// even over a white video frame).
  static const chatScrim = Color(0x99000000);
}

/// `color.onStatus` (v1.1): text/icons on status, gold and PK fills.
abstract final class KStatusColors {
  static const onStatus = Color(0xFF0B0B0D);
}

/// `color.dark` / `color.light`.
@immutable
class KPalette {
  const new({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.scrim,
    required this.primaryText,
    required this.borderStrong,
    required this.focusRing,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color onPrimary;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color scrim;

  /// v1.1: red used as text/icon (links, selected labels). Never `primary`
  /// for text on dark.
  final Color primaryText;

  /// v1.1: input/toggle boundaries (≥ 3:1). `border` is decorative only.
  final Color borderStrong;

  /// v1.1: focus indicators.
  final Color focusRing;

  /// `scrim` is given as `#B3000000`, read as `#AARRGGBB` (70 % black).
  static const dark = KPalette(
    background: Color(0xFF0B0B0D),
    surface: Color(0xFF16161A),
    surfaceRaised: Color(0xFF1F1F25),
    surfaceOverlay: Color(0xFF2A2A32),
    border: Color(0xFF34343D),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB4B4BE),
    textTertiary: Color(0xFF92929E),
    primary: Color(0xFFE50914),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF5A623),
    error: Color(0xFFFF5A5F),
    info: Color(0xFF4DA3FF),
    scrim: Color(0xB3000000),
    primaryText: Color(0xFFFF3B47),
    borderStrong: Color(0xFF70707C),
    focusRing: Color(0xFFFF3B47),
  );

  /// `scrim` is given as `#99000000`, read as `#AARRGGBB` (60 % black).
  static const light = KPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F6F8),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceOverlay: Color(0xFFECECF0),
    border: Color(0xFFDCDCE2),
    textPrimary: Color(0xFF0B0B0D),
    textSecondary: Color(0xFF4A4A55),
    textTertiary: Color(0xFF666671),
    primary: Color(0xFFC8080F),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF137A43),
    warning: Color(0xFF955C00),
    error: Color(0xFFC4242D),
    info: Color(0xFF1A64BF),
    scrim: Color(0x99000000),
    primaryText: Color(0xFFC8080F),
    borderStrong: Color(0xFF85858F),
    focusRing: Color(0xFFC8080F),
  );
}

/// `spacing`
abstract final class KSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// `radius`
abstract final class KRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

/// `typography`
abstract final class KFonts {
  static const latin = 'Inter';
  static const arabic = 'Readex Pro';

  /// Arabic locales use Readex Pro (D47; the bundled files also cover
  /// Latin); other locales use Inter with Readex Pro as fallback for Arabic
  /// text.
  static String familyFor(Locale locale) =>
      locale.languageCode == 'ar' ? arabic : latin;

  static List<String> fallbackFor(Locale locale) =>
      locale.languageCode == 'ar' ? const [latin] : const [arabic];
}

/// One entry of `typography.scale`.
@immutable
class KTypeScale {
  const new(this.size, this.weight, this.height);

  final double size;
  final FontWeight weight;
  final double height;

  TextStyle toStyle({
    required String family,
    required List<String> fallback,
    required Color color,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
  );
}

abstract final class KTypography {
  static const display = KTypeScale(32, FontWeight.w700, 1.2);
  static const headline = KTypeScale(24, FontWeight.w700, 1.25);
  static const title = KTypeScale(18, FontWeight.w600, 1.3);
  static const body = KTypeScale(15, FontWeight.w400, 1.45);
  static const bodyStrong = KTypeScale(15, FontWeight.w600, 1.45);
  static const label = KTypeScale(13, FontWeight.w600, 1.3);
  static const caption = KTypeScale(12, FontWeight.w400, 1.35);
}

/// `motion`
abstract final class KMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const Curve standard = Curves.easeOutCubic;
  static const respectReduceMotion = true;

  /// v1.1: gift combo ×N counter bump.
  static const giftComboBump = Duration(milliseconds: 120);

  /// Returns [duration], or zero when the platform asks to reduce motion.
  static Duration of(BuildContext context, Duration duration) =>
      respectReduceMotion && MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : duration;
}

/// `size`
abstract final class KSizes {
  static const double minTouchTarget = 48;
  static const double avatarSm = 32;
  static const double avatarMd = 48;
  static const double avatarLg = 88;
  static const double storyRing = 68;
  static const double bottomNavHeight = 64;
  static const double buttonHeight = 52;

  /// v1.1: live cover card width / height (3:4).
  static const double liveCardAspect = 0.75;

  /// v1.1: columns in the gift panel grid.
  static const int giftGridColumns = 4;
}
