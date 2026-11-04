import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_ref_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D258 (owner: «اجعل طريقة العرض هكذا», reference 38): the «شراء VIP» page
/// shows the tier's big badge on a stage with a soft glow in the tier's
/// colour, then a panel with a curved top holding «التعريف» and a 3-column
/// grid of square tiles — each a live preview of the actual perk (the frame
/// around a sample picture, the entry banner, the coloured name, the card,
/// the car …) or, for a perk without art, its icon and value — the perk's
/// title under it. The page keeps the owner's white / black background.
class VipStage extends StatelessWidget {
  const new({required this.tier, super.key});

  final VipTier tier;

  static const double height = 250;
  static const double badge = 200;

  @override
  Widget build(BuildContext context) {
    final accent = Color(tier.color);
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The glow behind the badge, in the tier's colour.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.62,
                  colors: [
                    accent.withValues(alpha: 0.55),
                    accent.withValues(alpha: 0.18),
                    accent.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          VipBadge(tier: tier, size: badge),
        ],
      ),
    );
  }
}

/// The panel under the stage: a curved top edge (a thin line in the tier's
/// colour along the arc), «التعريف» between two ornaments, and the tiles.
class VipIdentityPanel extends StatelessWidget {
  const new({required this.tier, required this.active, super.key});

  final VipTier tier;

  /// The caller holds this tier (or a higher one): nothing dimmed.
  final bool active;

  static const panelKey = Key('vip.identity');

  /// How high the arc rises at the panel's middle.
  static const double arc = 22;

  @override
  Widget build(BuildContext context) {
    final p = VipPalette.of(context);
    final l10n = context.l10n;
    final t = context.textStyles;
    final accent = Color(tier.color);
    // On the tier-coloured page: a deeper shade of the tier.
    final fill = Color.lerp(accent, const Color(0xFF000000), 0.7)!;
    final ornament = Color.lerp(accent, const Color(0xFFFFE08A), 0.5)!;
    return CustomPaint(
      key: panelKey,
      painter: _ArcPanelPainter(fill: fill, edge: ornament),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, arc + 14, 12, 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Flourish(color: ornament),
                const SizedBox(width: 10),
                Text(
                  l10n.vipIdentity,
                  style: t.title.copyWith(
                    color: p.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Transform.flip(flipX: true, child: _Flourish(color: ornament)),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, box) {
                const columns = 3;
                const gap = 12.0;
                final tile = (box.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: 14,
                  children: [
                    for (final perk in tier.perks)
                      SizedBox(
                        width: tile,
                        child: _PerkTile(
                          key: Key('vip.perk.${perk.code}'),
                          tier: tier,
                          perk: perk,
                          size: tile,
                          dimmed: !perk.available && !active,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A small ornament beside the header (a curl and a dot, in the tier's
/// gold-tinted colour).
class _Flourish extends StatelessWidget {
  const new({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(34, 12), painter: _FlourishPainter(color));
}

class _FlourishPainter extends CustomPainter {
  new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..quadraticBezierTo(
        size.width * 0.35,
        0,
        size.width * 0.6,
        size.height / 2,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height,
        size.width,
        size.height / 2,
      );
    canvas
      ..drawPath(path, paint)
      ..drawCircle(
        Offset(size.width * 0.6, size.height / 2),
        1.6,
        paint..style = PaintingStyle.fill,
      );
  }

  @override
  bool shouldRepaint(_FlourishPainter old) => old.color != color;
}

class _ArcPanelPainter extends CustomPainter {
  new({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  Path _top(Size size) => Path()
    ..moveTo(0, VipIdentityPanel.arc)
    ..quadraticBezierTo(
      size.width / 2,
      -VipIdentityPanel.arc,
      size.width,
      VipIdentityPanel.arc,
    );

  @override
  void paint(Canvas canvas, Size size) {
    final body = _top(size)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(body, Paint()..color = fill)
      ..drawPath(
        _top(size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..shader = LinearGradient(
            colors: [
              edge.withValues(alpha: 0),
              edge,
              edge.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
  }

  @override
  bool shouldRepaint(_ArcPanelPainter old) =>
      old.fill != fill || old.edge != edge;
}

/// One square tile: a live preview of the perk (or its icon and value) in a
/// thin tier-coloured border, its title under it.
class _PerkTile extends StatelessWidget {
  const new({
    required this.tier,
    required this.perk,
    required this.size,
    required this.dimmed,
    super.key,
  });

  final VipTier tier;
  final VipPerk perk;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = VipPalette.of(context);
    final t = context.textStyles;
    final accent = Color(tier.color);
    final tile = Color.lerp(accent, const Color(0xFF000000), 0.82)!;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tile,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
            child: Semantics(
              image: true,
              label: perk.title,
              child: _Preview(tier: tier, perk: perk, size: size - 16),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            perk.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(color: p.text, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// The perk shown as it looks: its art (framing a sample picture for a
/// frame or a mic wave), a sample name in the special colour, or its icon
/// and value.
class _Preview extends StatelessWidget {
  const new({required this.tier, required this.perk, required this.size});

  final VipTier tier;
  final VipPerk perk;
  final double size;

  bool get _hasArt => perk.still != null || perk.animation != null;

  Widget _art({BoxFit fit = BoxFit.contain}) =>
      VipAnimatedArt(animation: perk.animation, still: perk.still, fit: fit);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = VipPalette.of(context);
    final t = context.textStyles;
    final sample = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.iconFill,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 1.5),
      ),
      child: Icon(Icons.person_rounded, color: p.icon, size: size * 0.3),
    );
    switch (perk.code) {
      case VipPerks.avatarFrame || VipPerks.micWave when _hasArt:
        // The frame (or the wave) around a sample picture.
        final hole = perk.code == VipPerks.avatarFrame ? 0.5 : 0.42;
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(dimension: size * hole, child: sample),
            Positioned.fill(child: _art()),
          ],
        );
      case VipPerks.nameColor:
        final special = tier.nameColor == null
            ? vipNameTint(Color(tier.color))
            : Color(tier.nameColor!);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(dimension: size * 0.36, child: sample),
            const SizedBox(height: 6),
            Text(
              l10n.vipPreviewName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(
                color: special,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      default:
        if (_hasArt) return _art();
        return _Value(perk: perk, size: size);
    }
  }
}

/// A perk without art: its icon in a soft circle and its value («٣ يومياً»,
/// «+1٪»).
class _Value extends StatelessWidget {
  const new({required this.perk, required this.size});

  final VipPerk perk;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = VipPalette.of(context);
    final t = context.textStyles;
    final amount = perk.amount;
    final value = switch ((perk.code, amount)) {
      (VipPerks.dailyBullet, final n?) => l10n.vipPerkPerDay('$n'),
      (VipPerks.dailyCoins, final n?) => l10n.vipPerkPerDay(KFormat.grouped(n)),
      (VipPerks.levelSpeedup, final n?) => '+$n%',
      _ => null,
    };
    final double icon = math.min(size * 0.42, 40);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: icon,
          height: icon,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.iconFill),
          child: Icon(
            VipPrivilegeCard.iconOf(perk.code),
            size: icon * 0.55,
            color: p.icon,
          ),
        ),
        if (value != null) ...[
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: value.startsWith('+') ? TextDirection.ltr : null,
            style: t.body.copyWith(color: p.text, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}
