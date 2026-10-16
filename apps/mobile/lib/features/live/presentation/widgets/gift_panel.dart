import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Gift panel shell (G-10, DESIGN_SYSTEM §9.11): always-dark bottom sheet,
/// top radius `xl`, 32×4 handle, title row with close at the end, a
/// `size.giftGridColumns` (4) grid with `sm` gaps, a selected cell with a
/// 1.5 dp `gold` outline on `surfaceOverlay`, and the ×N combo counter.
///
/// Sending is **disabled**: purchases and gifting are blocked on B5, so the
/// footer shows a disabled Send button and a "coming soon" caption.
class KGiftPanel extends StatelessWidget {
  const new({
    required this.gifts,
    super.key,
    this.selectedId,
    this.onSelected,
    this.comboCount = 0,
    this.onClose,
  });

  final List<GiftItemData> gifts;
  final String? selectedId;
  final ValueChanged<GiftItemData>? onSelected;

  /// Consecutive taps on the selected gift; the ×N counter shows from 2.
  final int comboCount;
  final VoidCallback? onClose;

  /// Shows the panel as a modal bottom sheet (scrim, drag to dismiss).
  static Future<void> show(
    BuildContext context, {
    required WidgetBuilder builder,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KPalette.dark.surfaceRaised.withValues(alpha: 0),
    barrierColor: KPalette.dark.scrim,
    constraints: BoxConstraints(
      maxHeight:
          MediaQuery.sizeOf(context).height * KMetrics.sheetMaxHeightFactor,
    ),
    builder: (context) => KLiveSurface(child: builder(context)),
  );

  @override
  Widget build(BuildContext context) =>
      KLiveSurface(child: Builder(builder: _build));

  Widget _build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final text = context.textStyles;
    return Container(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: KSpacing.sm),
            Center(
              child: Container(
                width: KMetrics.sheetHandleWidth,
                height: KMetrics.sheetHandleHeight,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: KSpacing.lg,
                end: KSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l10n.giftPanelTitle, style: text.title),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        onClose ?? () => Navigator.maybeOf(context)?.maybePop(),
                    tooltip: l10n.liveClose,
                    icon: Icon(Icons.close, color: p.textPrimary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: GridView.count(
                crossAxisCount: KSizes.giftGridColumns,
                mainAxisSpacing: KSpacing.sm,
                crossAxisSpacing: KSpacing.sm,
                childAspectRatio: KMetrics.giftCellAspect,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final gift in gifts)
                    _GiftCell(
                      gift: gift,
                      selected: gift.id == selectedId,
                      onTap: onSelected == null
                          ? null
                          : () => onSelected!(gift),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (comboCount > 1) ...[
                          KGiftComboCounter(count: comboCount),
                          const SizedBox(width: KSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            l10n.giftSendComingSoon,
                            style: text.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  KButton(
                    label: l10n.giftSend,
                    onPressed: null,
                    expand: false,
                    icon: Icons.send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "×N" combo counter. Each new [count] bumps the scale for
/// `motion.giftComboBumpMs`; with reduce motion it changes instantly.
class KGiftComboCounter extends StatelessWidget {
  const new({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final duration = KMotion.of(context, KMotion.giftComboBump);
    final label = Text(
      context.l10n.giftCombo(count),
      style: context.textStyles.title.copyWith(
        color: KBrandColors.gold,
        fontWeight: FontWeight.w700,
      ),
    );
    if (duration == Duration.zero) return label;
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: KMetrics.giftComboBumpScale, end: 1),
      duration: duration,
      curve: KMotion.standard,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: label,
    );
  }
}

class _GiftCell extends StatelessWidget {
  const new({required this.gift, required this.selected, this.onTap});

  final GiftItemData gift;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.textStyles;
    final price = KFormat.grouped(gift.price);
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.giftCellSemantics(gift.name, price),
      child: ExcludeSemantics(
        child: Material(
          color: selected ? p.surfaceOverlay : p.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KRadius.md),
            side: selected
                ? const BorderSide(
                    color: KBrandColors.gold,
                    width: KMetrics.thinStroke,
                  )
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KGiftArt(shape: gift.shape),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    gift.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(color: p.textPrimary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        size: KMetrics.iconXs,
                        color: KBrandColors.gold,
                      ),
                      const SizedBox(width: KSpacing.xxs),
                      Text(
                        price,
                        style: text.caption.copyWith(color: KBrandColors.gold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kabso placeholder gift art: flat token-coloured shapes (no third-party
/// artwork) until real assets exist.
class KGiftArt extends StatelessWidget {
  const new({required this.shape, super.key, this.size = KMetrics.giftArt});

  final GiftShape shape;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _GiftPainter(shape)),
  );
}

class _GiftPainter extends CustomPainter {
  const new(this.shape);

  final GiftShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final (path, colors) = switch (shape) {
      GiftShape.heart => (_heart(w, h), KBrandColors.gradientLive),
      GiftShape.star => (
        _star(rect.center, w / 2),
        const [KBrandColors.gold, KBrandColors.gold],
      ),
      GiftShape.diamond => (
        _diamond(w, h),
        const [KLiveColors.pkRight, KLiveColors.pkLeft],
      ),
      GiftShape.crown => (
        _crown(w, h),
        const [KBrandColors.gold, KBrandColors.red400],
      ),
    };
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  // Shapes are drawn in proportions of the art box (geometry, not tokens).

  static Path _heart(double w, double h) => Path()
    ..moveTo(w / 2, h * 0.9)
    ..cubicTo(w * 0.05, h * 0.6, w * 0.05, h * 0.15, w * 0.3, h * 0.15)
    ..cubicTo(w * 0.42, h * 0.15, w / 2, h * 0.25, w / 2, h * 0.32)
    ..cubicTo(w / 2, h * 0.25, w * 0.58, h * 0.15, w * 0.7, h * 0.15)
    ..cubicTo(w * 0.95, h * 0.15, w * 0.95, h * 0.6, w / 2, h * 0.9)
    ..close();

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r * 0.95 : r * 0.42;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = c + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  static Path _diamond(double w, double h) => Path()
    ..moveTo(w * 0.25, h * 0.2)
    ..lineTo(w * 0.75, h * 0.2)
    ..lineTo(w * 0.92, h * 0.4)
    ..lineTo(w / 2, h * 0.88)
    ..lineTo(w * 0.08, h * 0.4)
    ..close();

  static Path _crown(double w, double h) => Path()
    ..moveTo(w * 0.12, h * 0.78)
    ..lineTo(w * 0.08, h * 0.28)
    ..lineTo(w * 0.32, h * 0.5)
    ..lineTo(w / 2, h * 0.18)
    ..lineTo(w * 0.68, h * 0.5)
    ..lineTo(w * 0.92, h * 0.28)
    ..lineTo(w * 0.88, h * 0.78)
    ..close();

  @override
  bool shouldRepaint(_GiftPainter oldDelegate) => oldDelegate.shape != shape;
}
