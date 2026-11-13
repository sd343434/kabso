import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/medals/presentation/medals_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The medals page's look in the app theme (D291, owner art 2026-11-06,
/// `assets/medals/PROVENANCE.md`): the owner's light or dark page
/// background, and text / panel colours chosen for ≥ 4.5:1 on it — dark
/// text over the white-and-gold background, light and gold text over the
/// purple one. The pedestal and the card frame are the same in both.
@immutable
class MedalsLook {
  const new _(this.dark);

  factory of(BuildContext context) =>
      MedalsLook._(Theme.of(context).brightness == Brightness.dark);

  /// For contrast tests.
  @visibleForTesting
  factory test({required bool dark}) => MedalsLook._(dark);

  final bool dark;

  static const bgDark = 'assets/medals/medals_bg_dark.webp';
  static const bgLight = 'assets/medals/medals_bg_light.webp';
  static const pedestalDark = 'assets/medals/medals_stage_pedestal.webp';
  static const pedestalLight = 'assets/medals/medals_stage_pedestal_light.webp';
  static const cardFrame = 'assets/medals/medal_card_frame.webp';

  /// The card frame's own aspect (600 × 800).
  static const cardAspect = 0.75;

  /// The frame's transparent inner area, as fractions of the card
  /// (measured on the owner's file: x 14.3–85.7 %, y 21–85 %).
  static const ({double left, double top, double right, double bottom})
  cardInner = (left: 0.15, top: 0.215, right: 0.15, bottom: 0.16);

  /// The gold of the selected tab and the pills (`color.brand.gold` with a
  /// lighter top and a deeper bottom; dark text on it is ≥ 10:1).
  static const goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE29A), KBrandColors.gold, Color(0xFFE0A93A)],
  );

  String get background => dark ? bgDark : bgLight;

  /// The owner's dark pedestal, or his gold-and-white one in the light theme.
  String get pedestal => dark ? pedestalDark : pedestalLight;

  /// Under the background while it decodes (its main colour).
  Color get base => dark ? const Color(0xFF1A0730) : const Color(0xFFFBF8F4);

  /// ≥ 15:1 on the background and on [cardFill].
  Color get text => dark ? Colors.white : const Color(0xFF1E1230);

  /// ≥ 9:1 on the background, [panel] and [cardFill].
  Color get textSecondary =>
      dark ? const Color(0xFFDCD0EA) : const Color(0xFF4A3D57);

  /// The light theme's title (gold on white would be 1.6:1): ≈ 7:1.
  Color get titleSolid => const Color(0xFF7A4E00);

  /// The status line and the tab bar.
  Color get panel => dark ? const Color(0x8C12061F) : const Color(0xD9FFFFFF);
  Color get panelBorder =>
      dark ? const Color(0x40F5C451) : const Color(0x80C9932A);

  /// Inside the card frame.
  Color get cardFill =>
      dark ? const Color(0xF2190A2B) : const Color(0xF7FFFFFF);

  Color get track => dark ? const Color(0x33FFFFFF) : const Color(0x262A1840);

  /// The progress bar (non-text, ≥ 3:1 on [cardFill]).
  Color get bar => dark ? KBrandColors.gold : const Color(0xFFA86F00);

  Color get mutedPill =>
      dark ? const Color(0x29FFFFFF) : const Color(0xFFEDE6F2);

  SystemUiOverlayStyle get overlay =>
      dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}

/// «الميداليات التي أرتديها» (D291, §10.104.6): the title between two gold
/// rules, then the owner's pedestal for the theme (scaled to the width,
/// aspect kept) with exactly ONE earned medal standing on its top surface
/// (owner: «عرض الميدالية يكون للميداليات التي تم فتحها وتعرض على المنصة
/// ميدالية واحدة فقط»), large (no number on it), with its name and level
/// under it; a short scale-in when it changes. With none ([staged] null: no
/// earned medal): a dashed hexagon on the pedestal, the pill «غير مرتدية»
/// and «لا ترتدي أي ميدالية». The line under it counts what the profile
/// shows ([wornCount] of [maxShowcaseMedals]).
class MedalStage extends StatelessWidget {
  const new({
    required this.staged,
    required this.wornCount,
    required this.onOpen,
    super.key,
  });

  final MedalCardData? staged;
  final int wornCount;
  final ValueChanged<MedalCardData> onOpen;

  static const stageKey = Key('medals.stage');
  static const emptyKey = Key('medals.stage.empty');
  static const notWornKey = Key('medals.stage.not_worn');
  static const pedestalKey = Key('medals.stage.pedestal');
  static const nameKey = Key('medals.stage.name');

  static Key stagedKey(String code) => Key('medals.stage.medal.$code');

  /// Where the medal stands: this share of the pedestal's height from its
  /// top (the top disc, measured on both of the owner's files).
  static const standAt = 0.57;

  /// The staged medal's size on a pedestal [width] wide.
  static double sizeFor(double width) => width * 0.34;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final look = MedalsLook.of(context);
    final m = staged;
    final t = context.textStyles;
    return Column(
      key: stageKey,
      children: [
        _Title(text: l10n.medalsStageTitle, look: look),
        const SizedBox(height: KSpacing.xs),
        LayoutBuilder(
          builder: (context, box) {
            final w = math.min(box.maxWidth, 440).toDouble();
            final h = w / 2;
            final hex = w * 0.2;
            final size = sizeFor(w);
            // Room above the pedestal for the part of the medal that rises
            // over its box, so it never touches the title.
            final rise = math.max(0, size - h * standAt).toDouble();
            return Padding(
              padding: EdgeInsets.only(top: rise + KSpacing.sm),
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        look.pedestal,
                        key: pedestalKey,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                      ),
                    ),
                    if (m == null) ...[
                      Positioned(
                        left: (w - hex) / 2,
                        top: h * standAt - hex * 1.12,
                        child: SizedBox(
                          key: emptyKey,
                          width: hex,
                          height: hex * 1.12,
                          child: CustomPaint(painter: _HexagonPainter(look)),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.62,
                        child: Center(
                          child: Container(
                            key: notWornKey,
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.xl,
                              vertical: KSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              gradient: MedalsLook.goldGradient,
                              borderRadius: BorderRadius.circular(KRadius.pill),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              l10n.medalsNotWorn,
                              style: t.bodyStrong.copyWith(
                                color: KStatusColors.onStatus,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Positioned(
                        left: (w - size) / 2,
                        top: h * standAt - size,
                        width: size,
                        height: size,
                        child: AnimatedSwitcher(
                          duration: KMotion.slow,
                          switchInCurve: Curves.easeOutBack,
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.6,
                                end: 1,
                              ).animate(a),
                              alignment: Alignment.bottomCenter,
                              child: child,
                            ),
                          ),
                          child: Semantics(
                            key: ValueKey(m.code),
                            button: true,
                            label: l10n.medalsCardLabel(
                              m.name,
                              l10n.medalsLevel(m.level),
                            ),
                            excludeSemantics: true,
                            child: GestureDetector(
                              key: stagedKey(m.code),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onOpen(m),
                              child: MedalIcon(
                                iconKey: m.iconKey,
                                iconUrl: m.iconUrl,
                                iconAsset: m.iconAsset,
                                size: size,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (m != null)
          Padding(
            key: nameKey,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
            child: Text(
              '${m.name} · ${l10n.medalsLevel(m.level)}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodyStrong.copyWith(color: look.text),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.xl,
            KSpacing.sm,
            KSpacing.xl,
            0,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: look.panel,
              borderRadius: BorderRadius.circular(KRadius.sm),
              border: Border.all(color: look.panelBorder),
            ),
            child: Text(
              wornCount == 0
                  ? l10n.medalsNoneWorn
                  : l10n.medalsProfileWornCount(wornCount, maxShowcaseMedals),
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: look.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

/// The title between two short gold rules: gold over the dark background,
/// a deep gold (≈ 7:1) over the light one.
class _Title extends StatelessWidget {
  const new({required this.text, required this.look});

  final String text;
  final MedalsLook look;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    Widget rule({required bool leading}) => Flexible(
      child: Container(
        height: 1.5,
        constraints: const BoxConstraints(maxWidth: 56),
        margin: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              KBrandColors.gold.withValues(alpha: leading ? 0 : 0.9),
              KBrandColors.gold.withValues(alpha: leading ? 0.9 : 0),
            ],
          ),
        ),
      ),
    );
    final style = t.headline.copyWith(
      color: look.dark ? Colors.white : look.titleSolid,
    );
    final title = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 2,
      style: style,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          rule(leading: true),
          Flexible(
            flex: 4,
            child: look.dark
                ? ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: MedalsLook.goldGradient.createShader,
                    child: title,
                  )
                : title,
          ),
          rule(leading: false),
        ],
      ),
    );
  }
}

/// The empty place: a dashed hexagon with a faint fill.
class _HexagonPainter extends CustomPainter {
  const new(this.look);

  final MedalsLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 2;
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i - math.pi / 2;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        hex.moveTo(p.dx, p.dy);
      } else {
        hex.lineTo(p.dx, p.dy);
      }
    }
    hex.close();
    final ink = look.dark ? Colors.white : const Color(0xFF5B2E8C);
    canvas.drawPath(hex, Paint()..color = ink.withValues(alpha: 0.08));
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = ink.withValues(alpha: 0.7);
    for (final metric in hex.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 5, metric.length)),
          dash,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) =>
      oldDelegate.look.dark != look.dark;
}
