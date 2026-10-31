import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:material_ui/material_ui.dart';

/// D199: the booster's owner-made tier (assets/pk/pk_power_*, the score
/// bar's t1–t4): «دبل» → Double, «دبل تيربو» → Double Turbo, «تربل» →
/// Triple, «تربل تيربو» → Triple Turbo.
PkPowerTier pkPowerTier(PkBoosterKind kind) => switch (kind) {
  PkBoosterKind.double => PkPowerTier.doublePower,
  PkBoosterKind.doubleTurbo => PkPowerTier.doubleTurbo,
  PkBoosterKind.triple => PkPowerTier.triple,
  PkBoosterKind.tripleTurbo => PkPowerTier.tripleTurbo,
};

/// D199 (owner «بنفس المكان الذي في الصورة وبنفس الحجم»): the owner's
/// banners sit where D195's announcement pill was — centred across both
/// video boxes, its centre 37.5 % down them (the pill's `Alignment(0,
/// -0.25)`), 52 % of the stage's width (204 lp at 393), the height following
/// the art.
abstract final class PkStageBanner {
  static const widthFactor = 0.52;

  /// The tallest art's height / width (Triple Turbo, 478 / 1440).
  static const double _aspect = 478 / 1440;

  static double height(double width) => width * widthFactor * _aspect;

  static double top(double width, double paneHeight) =>
      paneHeight * 0.375 - height(width) / 2;

  /// The «فعّل فريق …» line under the banner (under both when both sides
  /// are boosted: the owner's layer stacks the second at 0.9 × its height).
  static double captionTop(
    double width,
    double paneHeight, {
    required bool both,
  }) => top(width, paneHeight) + height(width) * (both ? 1.9 : 1) + 4;
}

/// D199 text fix: D195 drew «فعّل فريق …» in the app's Arabic face (Readex
/// Pro) at bold, whose medial «ع» fills its counter, so with the shadda above
/// it «فعّل» read «فقل» (measured at 15 lp @3x). Baloo Bhaijaan 2 ExtraBold
/// (bundled, OFL) keeps the «ع» open and the shadda clear; Latin falls back
/// to Inter.
abstract final class PkBoostText {
  static const family = 'Baloo Bhaijaan 2';
  static const lineKey = Key('pk.boost.line');
}

TextStyle pkBoostLineStyle(BuildContext context) =>
    context.textStyles.bodyStrong.copyWith(
      fontFamily: PkBoostText.family,
      fontFamilyFallback: const ['Inter'],
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: const Color(0xFFFFFFFF),
      shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 4)],
    );
