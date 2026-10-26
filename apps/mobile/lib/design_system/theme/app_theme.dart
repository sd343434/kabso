import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Token text styles resolved for a palette and locale.
@immutable
class KTextStyles {
  const new({
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
  });

  factory resolve(KPalette palette, Locale locale) {
    final family = KFonts.familyFor(locale);
    final fallback = KFonts.fallbackFor(locale);
    TextStyle s(KTypeScale scale, Color color) =>
        scale.toStyle(family: family, fallback: fallback, color: color);
    return KTextStyles(
      display: s(KTypography.display, palette.textPrimary),
      headline: s(KTypography.headline, palette.textPrimary),
      title: s(KTypography.title, palette.textPrimary),
      body: s(KTypography.body, palette.textPrimary),
      bodyStrong: s(KTypography.bodyStrong, palette.textPrimary),
      label: s(KTypography.label, palette.textPrimary),
      caption: s(KTypography.caption, palette.textSecondary),
    );
  }

  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle label;
  final TextStyle caption;
}

/// Exposes the raw tokens to widgets: `context.palette`, `context.textStyles`.
@immutable
class KTheme extends ThemeExtension<KTheme> {
  const new({required this.palette, required this.text});

  final KPalette palette;
  final KTextStyles text;

  @override
  KTheme copyWith({KPalette? palette, KTextStyles? text}) =>
      KTheme(palette: palette ?? this.palette, text: text ?? this.text);

  @override
  KTheme lerp(covariant KTheme? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension KThemeContext on BuildContext {
  KTheme get kTheme => Theme.of(this).extension<KTheme>()!;
  KPalette get palette => kTheme.palette;
  KTextStyles get textStyles => kTheme.text;
}

/// Builds the Material 3 theme from tokens.
ThemeData buildAppTheme({
  required Brightness brightness,
  required Locale locale,
}) {
  final p = brightness == Brightness.dark ? KPalette.dark : KPalette.light;
  final text = KTextStyles.resolve(p, locale);
  final family = KFonts.familyFor(locale);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: KBrandColors.gold,
    onSecondary: const Color(0xFF0B0B0D),
    tertiary: p.info,
    onTertiary: p.onPrimary,
    error: p.error,
    onError: p.onPrimary,
    surface: p.background,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceRaised,
    surfaceContainerHighest: p.surfaceOverlay,
    outline: p.border,
    outlineVariant: p.border,
    scrim: p.scrim,
    shadow: const Color(0xFF000000),
  );

  final textTheme = TextTheme(
    displaySmall: text.display,
    headlineSmall: text.headline,
    headlineMedium: text.headline,
    titleLarge: text.title,
    titleMedium: text.title,
    titleSmall: text.bodyStrong,
    bodyLarge: text.body,
    bodyMedium: text.body,
    bodySmall: text.caption,
    labelLarge: text.label,
    labelMedium: text.label,
    labelSmall: text.caption,
  );

  // v1.1: input outlines use `borderStrong` (≥ 3:1); focus uses `focusRing`.
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(KRadius.md),
    borderSide: BorderSide(color: p.borderStrong),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: family,
    fontFamilyFallback: KFonts.fallbackFor(locale),
    textTheme: textTheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.border,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [KTheme(palette: p, text: text)],
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.title,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: KSpacing.lg,
        vertical: KSpacing.md,
      ),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: p.focusRing, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: p.error)),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: p.error, width: 2),
      ),
      labelStyle: text.body.copyWith(color: p.textSecondary),
      hintStyle: text.body.copyWith(color: p.textTertiary),
      errorStyle: text.caption.copyWith(color: p.error),
      helperStyle: text.caption,
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceOverlay,
      contentTextStyle: text.body,
      actionTextColor: p.primaryText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surfaceRaised,
      titleTextStyle: text.title,
      contentTextStyle: text.body,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.lg),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.textPrimary,
      minTileHeight: KSizes.minTouchTarget,
      titleTextStyle: text.body,
      subtitleTextStyle: text.caption,
    ),
    dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(
      constraints: KMetrics.sheetConstraints(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        // Red text uses `primaryText` (v1.1).
        foregroundColor: p.primaryText,
        minimumSize: const Size(KSizes.minTouchTarget, KSizes.minTouchTarget),
        textStyle: text.label,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(KSizes.minTouchTarget, KSizes.minTouchTarget),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(KSizes.minTouchTarget, KSizes.minTouchTarget),
        selectedBackgroundColor: p.primary,
        selectedForegroundColor: p.onPrimary,
        foregroundColor: p.textPrimary,
        textStyle: text.label,
      ),
    ),
  );
}
