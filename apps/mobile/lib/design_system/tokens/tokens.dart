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

  /// D135 (owner: "more transparent frames"): the live's pills and chips
  /// (host pill, chips row, viewer count, quick replies) — black 22 %; their
  /// text carries [glassShadow].
  static const glass = Color(0x38000000);

  /// The text shadow on [glass] pills, so white text reads on bright video.
  static const glassShadow = [
    Shadow(color: Color(0x99000000), blurRadius: 3),
    Shadow(color: Color(0x66000000), offset: Offset(0, 0.5), blurRadius: 1),
  ];
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

/// `color.categoryAccent` (D386, v1.138-social, CONVENTIONS §10.175): the
/// accent of a verified account category's profile page, per family — the
/// cover tint, the category badge, the primary buttons and the featured
/// section. [dark] on the dark palette, [light] on the light one; each is
/// ≥ 4.5:1 against its page background. [onDark] / [onLight] is the text on
/// a filled accent.
class KCategoryAccents {
  const new({
    required this.music,
    required this.reciter,
    required this.word,
    required this.visual,
    required this.performer,
    required this.sportsGames,
    required this.lifestyle,
    required this.public,
  });

  final Color music;
  final Color reciter;
  final Color word;
  final Color visual;
  final Color performer;
  final Color sportsGames;
  final Color lifestyle;
  final Color public;

  static const dark = KCategoryAccents(
    music: Color(0xFFB388FF),
    reciter: Color(0xFF3DD6A3),
    word: Color(0xFFF0B45E),
    visual: Color(0xFF4FC9E8),
    performer: Color(0xFFFF6FAE),
    sportsGames: Color(0xFFFF9447),
    lifestyle: Color(0xFFA8D65A),
    public: Color(0xFFF5C451),
  );

  static const light = KCategoryAccents(
    music: Color(0xFF6A35D9),
    reciter: Color(0xFF0B7A55),
    word: Color(0xFF8F5A0E),
    visual: Color(0xFF0A6F8A),
    performer: Color(0xFFB8155A),
    sportsGames: Color(0xFFB04A06),
    lifestyle: Color(0xFF4E7A12),
    public: Color(0xFF8A6508),
  );

  /// Text and icons on a filled accent: the page's dark ink on the bright
  /// dark-mode accents, white on the deep light-mode ones.
  static const onDark = Color(0xFF0B0B0D);
  static const onLight = Color(0xFFFFFFFF);
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
  /// D255 (owner: «اريد نفس خط bigo live», the whole app; supersedes D47's
  /// Inter + Readex Pro): Roboto — Bigo's face on Android — and Noto Sans
  /// Arabic for Arabic, bundled so every phone draws the same.
  static const latin = 'Roboto';
  static const arabic = 'Noto Sans Arabic';

  /// D386: the poetry cards of a verified poet's «قصائدي» — the bundled
  /// Baloo Bhaijaan 2 (OFL, D64's welcome face), Roboto / Noto Sans Arabic
  /// for anything it lacks.
  static const poetry = 'Baloo Bhaijaan 2';

  /// Arabic locales use Noto Sans Arabic with Roboto for Latin runs; other
  /// locales use Roboto with Noto Sans Arabic for Arabic runs.
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
