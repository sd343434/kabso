import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
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

/// The agent badges next to a name: [RechargeAgentBadge] when [code] is set
/// (an ACTIVE recharge agent) and — v1.58-social (D189) — [HostAgentBadge]
/// when [hostCode] is set (a host agent), each with [gap] before it; both
/// when the person is both (owner proposal D189 c); nothing otherwise.
class RechargeAgentInlineBadge extends StatelessWidget {
  const new({
    required this.code,
    super.key,
    this.hostCode,
    this.height = 16,
    this.gap = 4,
  });

  final String? code;
  final String? hostCode;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final code = this.code;
    final hostCode = this.hostCode;
    if (code == null && hostCode == null) return const SizedBox.shrink();
    Widget pad(Widget child) => Padding(
      padding: EdgeInsetsDirectional.only(start: gap),
      child: child,
    );
    if (hostCode == null) {
      return pad(RechargeAgentBadge(code: code!, height: height));
    }
    if (code == null) {
      return pad(HostAgentBadge(code: hostCode, height: height));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pad(RechargeAgentBadge(code: code, height: height)),
        pad(HostAgentBadge(code: hostCode, height: height)),
      ],
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

/// The host-agent perks «وكيل مضيفين» (v1.58-social, D189, CONVENTIONS
/// §10.52): the owner's art in `assets/host_agent/` (PROVENANCE.md). Shown
/// only while the server says the person is a host agent (`hostAgent.code`:
/// the agency exists and is not suspended, any rank).
abstract final class HostAgentArt {
  static const frame = 'assets/host_agent/avatar_frame.webp';
  static const badge = 'assets/host_agent/badge.webp';
  static const entrance = 'assets/host_agent/entrance_bar.webp';

  /// The badge and the frame are square (240 × 240, 512 × 512).
  static const double badgeAspect = 1;
  static const double frameAspect = 1;

  /// The entrance bar's width / height (1050 × 389).
  static const double entranceAspect = 1050 / 389;
}

/// The host-agent badge «وكيل مضيفين»: placed exactly as
/// [RechargeAgentBadge] — beside the name on the profile and the person
/// card, and inline next to the name everywhere it shows in a live room.
/// Announced as «وكيل مضيفين host03».
class HostAgentBadge extends StatelessWidget {
  const new({required this.code, super.key, this.height = 18});

  final String code;

  /// The art's height; the width follows its proportions.
  final double height;

  static const badgeKey = Key('hostAgent.badge');

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.hostAgentBadgeLabel(KFormat.bidiIsolate(code)),
    excludeSemantics: true,
    child: Image.asset(
      HostAgentArt.badge,
      key: badgeKey,
      height: height,
      width: height * HostAgentArt.badgeAspect,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

/// The host-agent frame (owner's art): the person's photo in the round
/// opening. The art has no name plate, so no text is written. [width] is
/// the frame's width (it is square).
class HostAgentFrame extends StatelessWidget {
  const new({
    required this.width,
    required this.name,
    super.key,
    this.imageUrl,
    this.image,
  });

  final double width;
  final String name;
  final String? imageUrl;
  final ImageProvider? image;

  // Measured from the alpha channel of the trimmed square (PROVENANCE.md):
  // the opening's centre and radius as fractions of the side.
  static const double _cx = 0.4995;
  static const double _cy = 0.4815;
  static const double _r = 0.2645;

  /// The photo is drawn this much larger so its edge tucks under the ring.
  static const double _tuck = 1.04;

  static const frameKey = Key('hostAgent.frame');

  /// The frame's height for [width].
  static double heightFor(double width) => width / HostAgentArt.frameAspect;

  /// The frame width whose drawn photo is [picture] wide.
  static double widthForPicture(double picture) => picture / (2 * _r * _tuck);

  /// How far below the frame's top the picture's centre sits.
  static double pictureCentreY(double width) => heightFor(width) * _cy;

  @override
  Widget build(BuildContext context) {
    final picture = width * 2 * _r * _tuck;
    return Semantics(
      key: frameKey,
      label: context.l10n.hostAgentFrameLabel(KFormat.bidiIsolate(name)),
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: width,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: width * _cx - picture / 2,
              top: width * _cy - picture / 2,
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
                HostAgentArt.frame,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which agent frame a person wears around the profile / person-card photo.
enum AgentFrameKind { recharge, host }

/// Owner proposal D189 d (pending confirmation; the single place to change
/// it): the recharge-agent frame wins over the host-agent frame, and either
/// wins over a frame worn from the bag (or the CP frame).
AgentFrameKind? agentFrameKindFor({String? rechargeCode, String? hostCode}) =>
    rechargeCode != null
    ? AgentFrameKind.recharge
    : hostCode != null
    ? AgentFrameKind.host
    : null;

/// The geometry of the agent frames around an avatar-sized picture, so a
/// header can lay either out the same way. Owner (after D189): both are
/// drawn in the standard [AvatarFrameBox] — the recharge frame fills it,
/// the square host-agent frame is as high as it (no longer larger).
abstract final class AgentFrameGeometry {
  /// The frame's width in the standard box around a picture of [avatar].
  static double width(AgentFrameKind kind, double avatar) =>
      widthIn(kind, AvatarFrameBox.aroundAvatar(avatar));

  /// The frame's width fitted in [box].
  static double widthIn(AgentFrameKind kind, AvatarFrameBox box) =>
      switch (kind) {
        AgentFrameKind.recharge => box.fit(RechargeAgentArt.frameAspect).width,
        AgentFrameKind.host => box.fit(HostAgentArt.frameAspect).width,
      };

  static double height(AgentFrameKind kind, double width) => switch (kind) {
    AgentFrameKind.recharge => RechargeAgentFrame.heightFor(width),
    AgentFrameKind.host => HostAgentFrame.heightFor(width),
  };

  static double pictureCentreY(AgentFrameKind kind, double width) =>
      switch (kind) {
        AgentFrameKind.recharge => RechargeAgentFrame.pictureCentreY(width),
        AgentFrameKind.host => HostAgentFrame.pictureCentreY(width),
      };
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
