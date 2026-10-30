import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The recharge-agent perks (v1.54-social, D185, CONVENTIONS §10.48): the
/// owner's Kabi art in `assets/recharge_agent/` (PROVENANCE.md). They are
/// shown only while the server says the person is an ACTIVE agent
/// (`rechargeAgent.code`); a suspension removes them all at once.
abstract final class RechargeAgentArt {
  static const frame = 'assets/recharge_agent/avatar_frame.webp';
  static const badge = 'assets/recharge_agent/badge.webp';
  static const entrance = 'assets/recharge_agent/entrance_bar.webp';

  /// The badge art's width / height (1312 × 1199).
  static const double badgeAspect = 1312 / 1199;

  /// The frame art's width / height (1312 × 1199).
  static const double frameAspect = 1312 / 1199;

  /// The entrance bar's width / height (2000 × 667).
  static const double entranceAspect = 2000 / 667;

  /// The plate's red: the colour behind the code in the frame and the bar.
  static const plateText = Color(0xFFFFE9A8);
}

/// The recharge-agent badge «وكيل شحن»: on the profile and the person card
/// beside the name, and — owner, D185 — inline next to the agent's name
/// everywhere it shows in a live room (chat, the join line, the viewers
/// list, seats). Announced as «وكيل شحن coin0001».
class RechargeAgentBadge extends StatelessWidget {
  const new({required this.code, super.key, this.height = 18});

  final String code;

  /// The art's height; the width follows its proportions.
  final double height;

  static const badgeKey = Key('recharge.badge');

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.rechargeAgentBadgeLabel(KFormat.bidiIsolate(code)),
    excludeSemantics: true,
    child: Image.asset(
      RechargeAgentArt.badge,
      key: badgeKey,
      height: height,
      width: height * RechargeAgentArt.badgeAspect,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

/// [RechargeAgentBadge] when [code] is set (the person is an ACTIVE agent),
/// with [gap] before it; nothing otherwise.
class RechargeAgentInlineBadge extends StatelessWidget {
  const new({required this.code, super.key, this.height = 16, this.gap = 4});

  final String? code;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final code = this.code;
    if (code == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.only(start: gap),
      child: RechargeAgentBadge(code: code, height: height),
    );
  }
}

/// The agent frame (owner's art): the person's photo in the round opening
/// and the agent [code] in the red plate at the bottom, bold, fitted and
/// ellipsized (a Latin code reads left to right in both languages). [width]
/// is the frame's width; its height follows the art.
class RechargeAgentFrame extends StatelessWidget {
  const new({
    required this.width,
    required this.name,
    required this.code,
    super.key,
    this.imageUrl,
    this.image,
  });

  final double width;
  final String name;
  final String code;
  final String? imageUrl;
  final ImageProvider? image;

  // Measured on the original (1312 × 1199): the opening's centre and
  // radius, and the plate's text box.
  static const double _cx = 655 / 1312;
  static const double _cy = 590 / 1199;
  static const double _r = 375 / 1312;
  static const _plateLeft = 0.175;
  static const _plateRight = 0.823;
  static const _plateTop = 0.780;
  static const _plateBottom = 0.892;

  static const frameKey = Key('recharge.frame');
  static const plateKey = Key('recharge.frame.plate');

  /// The frame's height for [width].
  static double heightFor(double width) => width / RechargeAgentArt.frameAspect;

  /// The frame width whose opening is [picture] wide.
  static double widthForPicture(double picture) => picture / (2 * _r);

  /// How far below the frame's top the picture's centre sits.
  static double pictureCentreY(double width) => heightFor(width) * _cy;

  @override
  Widget build(BuildContext context) {
    final height = heightFor(width);
    final picture = width * 2 * _r * 1.02;
    final plateH = height * (_plateBottom - _plateTop);
    // Owner (D185, same day): the plate shows the display name — the
    // largest size from 62 % of the plate's height down to 42 % that fits on
    // one line, else ellipsized at 42 %.
    final nameDirection =
        KFormat.firstStrongDirection(name) ?? Directionality.of(context);
    final plateStyle = context.textStyles.title.copyWith(
      height: 1,
      fontWeight: FontWeight.w900,
      letterSpacing: plateH * 0.03,
    );
    final plateFont = rechargeFitFontSize(
      name,
      plateStyle,
      width * (_plateRight - _plateLeft) - 2 * plateH * 0.3,
      max: plateH * 0.62,
      min: plateH * 0.42,
      direction: nameDirection,
    );
    return Semantics(
      key: frameKey,
      label: context.l10n.rechargeAgentFrameLabel(
        KFormat.bidiIsolate(name),
        KFormat.bidiIsolate(code),
      ),
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: width * _cx - picture / 2,
              top: height * _cy - picture / 2,
              width: picture,
              height: picture,
              child: KAvatar(
                name: name,
                imageUrl: imageUrl,
                image: image,
                size: picture,
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                RechargeAgentArt.frame,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
            Positioned(
              left: width * _plateLeft,
              width: width * (_plateRight - _plateLeft),
              top: height * _plateTop,
              height: plateH,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: plateH * 0.3),
                  child: Text(
                    name,
                    key: plateKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textDirection: nameDirection,
                    textScaler: TextScaler.noScaling,
                    style: plateStyle.copyWith(
                      fontSize: plateFont,
                      color: RechargeAgentArt.plateText,
                      shadows: const [
                        Shadow(
                          color: Color(0xCC3A0000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether [text] in [style] fits [width] on one line.
bool rechargeTextFits(
  String text,
  TextStyle style,
  double width,
  TextDirection direction,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    maxLines: 1,
  )..layout();
  final fits = painter.width <= width;
  painter.dispose();
  return fits;
}

/// The largest font size from [max] down to [min] at which [text] fits
/// [width] on one line (else [min]; the text is then ellipsized).
double rechargeFitFontSize(
  String text,
  TextStyle style,
  double width, {
  required double max,
  required double min,
  TextDirection direction = TextDirection.ltr,
}) {
  for (var size = max; size > min; size -= 0.5) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontSize: size),
      ),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final fits = painter.width <= width;
    painter.dispose();
    if (fits) return size;
  }
  return min;
}
