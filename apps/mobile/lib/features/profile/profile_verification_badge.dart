// v1.90-social (D293, CONVENTIONS §10.105): the automatic verification badge
// «شارة التوثيق» beside a person's name.

import 'dart:math' as math;

import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/design_system/components/k_badge_explainer.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D293: the seal's colours, one per badge (the owner's spec). Kabso's own
/// colours, drawn in code — no copied art.
abstract final class VerificationBadgeColors {
  /// OWNER: a black seal with a gold rim and a gold brain.
  static const ownerSeal = Color(0xFF111111);
  static const ownerGold = Color(0xFFE8C25A);

  /// STAFF (the Kabso Team): red.
  static const staff = Color(0xFFD32F2F);

  /// RECHARGE_AGENT: gold.
  static const rechargeAgent = Color(0xFFC9971C);

  /// HOST_AGENT: green.
  static const hostAgent = Color(0xFF2E9D4F);

  /// CREATOR: purple.
  static const creator = Color(0xFF7B3FC4);

  /// VERIFIED_HOST: blue.
  static const verifiedHost = Color(0xFF1E88E5);

  static Color sealOf(VerificationBadge b) => switch (b) {
    VerificationBadge.owner => ownerSeal,
    VerificationBadge.staff => staff,
    VerificationBadge.rechargeAgent => rechargeAgent,
    VerificationBadge.hostAgent => hostAgent,
    VerificationBadge.creator => creator,
    VerificationBadge.verifiedHost => verifiedHost,
  };

  /// The icon's colour: white, the OWNER's gold.
  static Color inkOf(VerificationBadge b) =>
      b == VerificationBadge.owner ? ownerGold : const Color(0xFFFFFFFF);

  /// The rim: the OWNER's gold, none for the others.
  static Color? rimOf(VerificationBadge b) =>
      b == VerificationBadge.owner ? ownerGold : null;
}

/// D357 (owner, 2026-11-10: «ازيلها»): the badge a name actually shows —
/// the OWNER seal (black and gold) is never drawn, beside his name or on his
/// photo; the founder's only mark is his red photo seal (`FounderBadge`).
/// The server no longer sends `OWNER` (v1.118-social); this also covers a
/// cached or older payload.
VerificationBadge? shownVerification(VerificationBadge? b) =>
    b == VerificationBadge.owner ? null : b;

/// D293: the icon inside every seal. Owner 2026-11-06: «اجعلها كلها بصح
/// لكن الألوان مختلفة التي حددناها» — the same check mark in all six; only the
/// colours tell them apart (and the spoken label / tooltip say which one).
IconData verificationBadgeIcon(VerificationBadge b) => Icons.check_rounded;

/// The check's share of the seal: legible at the name-row size (a 23 lp seal
/// → a 14 lp check), inside the rosette's inner disc.
const double verificationIconScale = 0.6;

/// D293: the badge's kind in the app's language («وكيل شحن» / "recharge
/// agent").
String verificationBadgeKind(AppLocalizations l10n, VerificationBadge b) =>
    switch (b) {
      VerificationBadge.owner => l10n.verificationBadgeOwner,
      VerificationBadge.staff => l10n.verificationBadgeStaff,
      VerificationBadge.rechargeAgent => l10n.verificationBadgeRechargeAgent,
      VerificationBadge.hostAgent => l10n.verificationBadgeHostAgent,
      VerificationBadge.creator => l10n.verificationBadgeCreator,
      VerificationBadge.verifiedHost => l10n.verificationBadgeVerifiedHost,
    };

/// D293 (owner: «شارة التوثيق»): a rosette seal in the badge's colour with
/// its white check mark (the OWNER's gold), drawn [size] across (about the
/// name's line height, vertically centred with it), right after the display
/// name — the profile header (own and others') and the Me tab's name row.
/// Every seal carries the same check, so the spoken label and — D389 — the
/// explainer bubble on a tap say which one: «موثّق: وكيل شحن» / "Verified:
/// recharge agent". The seal is symmetric, so it reads the same right-to-left.
class ProfileVerificationBadge extends StatelessWidget {
  const new({
    required this.badge,
    super.key,
    this.size = 23,
    this.explain = true,
  });

  static const badgeKey = Key('profile.verificationBadge');

  /// D389: a tap shows what the seal is.
  final bool explain;

  /// The badge's size beside a name of [fontSize] (owner 2026-11-06: «نعم
  /// كبّرها»): about 1.0–1.1 × the name's line height — 23 lp for the
  /// profile header's 20 pt name, 21 for the Me tab's 18 — never under 14.
  static double sizeForFont(double fontSize) =>
      math.max(14, (fontSize * 1.15).roundToDouble());

  final VerificationBadge badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    // D357: the OWNER seal is never drawn.
    if (shownVerification(badge) == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final label = l10n.verificationBadgeLabel(
      verificationBadgeKind(l10n, badge),
    );
    // D389: a tap explains the seal (was a long-press tooltip).
    return KBadgeExplainer(
      message: l10n.badgeExplainVerification(
        verificationBadgeKind(l10n, badge),
      ),
      enabled: explain,
      child: Semantics(
        key: badgeKey,
        label: label,
        image: true,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: VerificationSealPainter(
              fill: VerificationBadgeColors.sealOf(badge),
              rim: VerificationBadgeColors.rimOf(badge),
            ),
            child: Center(
              child: Icon(
                verificationBadgeIcon(badge),
                size: size * verificationIconScale,
                color: VerificationBadgeColors.inkOf(badge),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D293 (owner 2026-11-06: «اجعل الشارة بشكل شارات توثيق»): the classic
/// "verified" rosette — a disc with [lobes] soft, rounded bumps (not teeth),
/// drawn from the polar curve r(θ) = R · (1 + [depth] · cos(lobes · θ)) /
/// (1 + depth), so its outermost points touch the box. An optional [rim]
/// stroke (the OWNER's gold).
class VerificationSealPainter extends CustomPainter {
  const new({required this.fill, this.rim, this.lobes = 8, this.depth = 0.075});

  final Color fill;
  final Color? rim;
  final int lobes;

  /// How deep the lobes are, as a share of the radius (gentle: 0.06–0.09).
  final double depth;

  /// The rosette's outline in a box of [size].
  static Path sealPath(Size size, {int lobes = 8, double depth = 0.075}) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    const samples = 192;
    final path = Path();
    for (var i = 0; i <= samples; i++) {
      // A lobe at the top (θ = −π/2), so the shape is upright and symmetric.
      final t = 2 * math.pi * i / samples;
      final r = outer * (1 + depth * math.cos(lobes * t)) / (1 + depth);
      final a = -math.pi / 2 + t;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rimColor = rim;
    final stroke = math.max<double>(1, size.shortestSide * 0.075);
    // A rim is drawn inside the box: the seal shrinks by half its width.
    final inset = rimColor == null ? 0.0 : stroke / 2;
    final box = Size(size.width - 2 * inset, size.height - 2 * inset);
    final path = sealPath(
      box,
      lobes: lobes,
      depth: depth,
    ).shift(Offset(inset, inset));
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..color = fill,
    );
    if (rimColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round
          ..color = rimColor,
      );
    }
  }

  @override
  bool shouldRepaint(VerificationSealPainter old) =>
      old.fill != fill ||
      old.rim != rim ||
      old.lobes != lobes ||
      old.depth != depth;
}

/// D293 (owner «نعم»: the badge beside the name everywhere the name
/// appears): the one small seal used next to a name in lists, chat lines,
/// search, post / comment authors, DMs, the viewers list and the person card
/// — [ProfileVerificationBadge] sized to the name's text ([fontSize], else
/// the ambient text style's), ≈ 1.15 × the font size and never under 14.
/// Draws nothing for no badge, so a call site can always place it.
class VerificationSeal extends StatelessWidget {
  const new(this.badge, {super.key, this.fontSize, this.gap = 3});

  static const sealKey = Key('verificationSeal');

  final VerificationBadge? badge;

  /// The name's font size (unscaled), or null for the ambient style's.
  final double? fontSize;

  /// The space before the seal (after the name), start side.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final b = shownVerification(badge);
    if (b == null) return const SizedBox.shrink();
    final font = fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: gap),
      child: ProfileVerificationBadge(
        key: sealKey,
        badge: b,
        size: ProfileVerificationBadge.sizeForFont(font),
      ),
    );
  }
}

/// D293: [name] followed by its [VerificationSeal] on one line — the name
/// shortens (ellipsis) first, the seal always shows.
class NameWithSeal extends StatelessWidget {
  const new({
    required this.name,
    required this.badge,
    super.key,
    this.fontSize,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  final Widget name;
  final VerificationBadge? badge;
  final double? fontSize;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (shownVerification(badge) == null) return name;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Flexible(child: name),
        VerificationSeal(badge, fontSize: fontSize),
      ],
    );
  }
}
