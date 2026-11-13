// v1.115-social (D354, CONVENTIONS §10.150): the event page designer's card
// presets and rules buttons (promoted from the KL-352 options prototype; the
// owner chose «اجعل كل الخيارات متاحة» — every option selectable per event).
//
// - [EventPageTheme]: a card theme applied to the designed page (cards,
//   tabs, the sticky «مركزي» bar, prize chips), five presets.
// - [EventRulesButtonStyle]: six ways to open the rules (in a bottom sheet).
//
// Kabso tokens only (brand reds, `KBrandColors.gold`, the event gold and the
// dark palette). No third-party art or shapes.

import 'dart:ui' as ui;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// ---------------------------------------------------------------------------
// Card theme.

/// A whole-page look for a gift event. Every colour comes from the Kabso
/// tokens (or a tint of one).
@immutable
class EventPageTheme {
  const new({
    required this.id,
    required this.cardFill,
    required this.cardBorder,
    required this.cardBorderWidth,
    required this.radius,
    required this.title,
    required this.accent,
    required this.text,
    required this.textMuted,
    required this.tileFill,
    required this.chipFill,
    required this.chipText,
    required this.meFill,
    required this.tabSelectedFill,
    required this.tabSelectedText,
    required this.tabFill,
    required this.tabText,
    required this.countdownFill,
    required this.countdownText,
    required this.barFill,
    required this.barText,
    required this.barHint,
    required this.scrim,
    this.blur = 0,
    this.glow = const [],
    this.titleShadow = const [],
    this.tileBorder,
    this.tabSelectedBorder,
    this.tabBorder,
    this.countdownBorder,
    this.barBorder,
  });

  final String id;

  /// Card body and its rim (a gradient stroke of [cardBorderWidth]).
  final Gradient cardFill;
  final Gradient cardBorder;
  final double cardBorderWidth;
  final double radius;

  /// Backdrop blur behind cards, bars and the countdown (0 = none).
  final double blur;
  final List<BoxShadow> glow;

  /// Section titles and the short bar before them.
  final Color title;
  final List<Shadow> titleShadow;
  final Gradient accent;

  /// Body text on cards (palette `textPrimary` / `textSecondary`).
  final Color text;
  final Color textMuted;

  final Color tileFill;
  final Color? tileBorder;
  final Color chipFill;
  final Color chipText;
  final Color meFill;

  final Gradient tabSelectedFill;
  final Color tabSelectedText;
  final Gradient? tabSelectedBorder;
  final Gradient tabFill;
  final Color tabText;
  final Gradient? tabBorder;

  final Gradient countdownFill;
  final Gradient? countdownBorder;
  final Color countdownText;

  final Gradient barFill;
  final Gradient? barBorder;
  final Color barText;
  final Color barHint;

  /// The darkening over the event's background, top to bottom.
  final List<Color> scrim;

  static EventPageTheme? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EventPageThemeScope>()?.theme;

  /// The page palette with this theme's text and surfaces.
  KPalette palette(KPalette base) => KPalette(
    background: base.background,
    surface: tileFill,
    surfaceRaised: tileFill,
    surfaceOverlay: base.surfaceOverlay,
    border: base.border,
    textPrimary: text,
    textSecondary: textMuted,
    textTertiary: textMuted,
    primary: base.primary,
    onPrimary: base.onPrimary,
    success: base.success,
    warning: base.warning,
    error: base.error,
    info: base.info,
    scrim: base.scrim,
    primaryText: base.primaryText,
    borderStrong: base.borderStrong,
    focusRing: base.focusRing,
  );

  /// Wraps [child] so the page's widgets draw with this theme.
  Widget apply(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final k = theme.extension<KTheme>()!;
    final palette = this.palette(k.palette);
    return Theme(
      data: theme.copyWith(
        extensions: [
          KTheme(
            palette: palette,
            text: KTextStyles.resolve(palette, Localizations.localeOf(context)),
          ),
        ],
      ),
      child: _EventPageThemeScope(theme: this, child: child),
    );
  }

  // --- The five presets ----------------------------------------------------

  static const ui.Color _gold = KBrandColors.gold; // #F5C451
  static const _goldLight = Color(0xFFFFE7A3); // gold tint (highlight)
  static const _goldDeep = Color(0xFFB7811A); // programGold on light
  static const _wine = Color(0xFF2A0508); // red700 shade (fills)

  static const _goldRim = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_goldLight, _gold, _goldDeep, _gold, _goldLight],
    stops: [0, 0.3, 0.55, 0.8, 1],
  );

  /// «ذهبي فاخر»: dark wine fills, gold gradient rims, a gold selected tab.
  static const luxuryGold = EventPageTheme(
    id: 'luxuryGold',
    cardFill: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xEB5A0A10), Color(0xF22A0508)],
    ),
    cardBorder: _goldRim,
    cardBorderWidth: 2,
    radius: 18,
    title: _gold,
    titleShadow: [Shadow(color: Color(0x99000000), blurRadius: 4)],
    accent: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_goldLight, _goldDeep],
    ),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFF1DDB0),
    tileFill: Color(0xCC1A0305),
    tileBorder: Color(0x80F5C451),
    chipFill: Color(0xFF3A0A0E),
    chipText: Color(0xFFFFFFFF),
    meFill: Color(0xFF3A0A0E),
    tabSelectedFill: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_goldLight, _gold, _goldDeep],
    ),
    tabSelectedText: _wine,
    tabFill: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [KBrandColors.red700, _wine],
    ),
    tabBorder: _goldRim,
    tabText: Color(0xFFFFE7A3),
    countdownFill: LinearGradient(
      colors: [KBrandColors.red700, _wine, KBrandColors.red700],
    ),
    countdownBorder: _goldRim,
    countdownText: _goldLight,
    barFill: LinearGradient(colors: [KBrandColors.red700, _wine]),
    barBorder: _goldRim,
    barText: Color(0xFFFFFFFF),
    barHint: _goldLight,
    scrim: [Color(0x33000000), Color(0x80000000), Color(0xB3000000)],
  );

  /// «زجاجي»: frosted dark glass over the art, hairline white rims.
  static const glass = EventPageTheme(
    id: 'glass',
    cardFill: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x66202026), Color(0x8C0B0B0D)],
    ),
    cardBorder: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x80FFFFFF), Color(0x1AFFFFFF), Color(0x4DFFFFFF)],
    ),
    cardBorderWidth: 1,
    radius: 22,
    blur: 18,
    title: Color(0xFFFFFFFF),
    titleShadow: [Shadow(color: Color(0x80000000), blurRadius: 4)],
    accent: LinearGradient(colors: [_gold, _gold]),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFD6D6DE),
    tileFill: Color(0x33FFFFFF),
    tileBorder: Color(0x33FFFFFF),
    chipFill: Color(0x33FFFFFF),
    chipText: Color(0xFFFFFFFF),
    meFill: Color(0x2EFFFFFF),
    tabSelectedFill: LinearGradient(
      colors: [Color(0xF2FFFFFF), Color(0xF2FFFFFF)],
    ),
    tabSelectedText: Color(0xFF0B0B0D),
    tabFill: LinearGradient(colors: [Color(0x26FFFFFF), Color(0x26FFFFFF)]),
    tabBorder: LinearGradient(colors: [Color(0x4DFFFFFF), Color(0x4DFFFFFF)]),
    tabText: Color(0xFFFFFFFF),
    countdownFill: LinearGradient(
      colors: [Color(0x59000000), Color(0x59000000)],
    ),
    countdownBorder: LinearGradient(
      colors: [Color(0x80FFFFFF), Color(0x33FFFFFF)],
    ),
    countdownText: Color(0xFFFFFFFF),
    barFill: LinearGradient(colors: [Color(0xA60B0B0D), Color(0xA60B0B0D)]),
    barBorder: LinearGradient(colors: [Color(0x66FFFFFF), Color(0x26FFFFFF)]),
    barText: Color(0xFFFFFFFF),
    barHint: _gold,
    scrim: [Color(0x26000000), Color(0x66000000), Color(0x99000000)],
  );

  /// «داكن بسيط»: the app's dark surfaces, flat, red selection.
  static const darkMinimal = EventPageTheme(
    id: 'darkMinimal',
    cardFill: LinearGradient(colors: [Color(0xF216161A), Color(0xF216161A)]),
    cardBorder: LinearGradient(colors: [Color(0xFF34343D), Color(0xFF34343D)]),
    cardBorderWidth: 1,
    radius: 12,
    title: Color(0xFFFFFFFF),
    accent: LinearGradient(colors: [KBrandColors.red500, KBrandColors.red500]),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFB4B4BE),
    tileFill: Color(0xFF1F1F25),
    chipFill: Color(0xFF2A2A32),
    chipText: Color(0xFFFFFFFF),
    meFill: Color(0xFF2A1416),
    tabSelectedFill: LinearGradient(
      colors: [KBrandColors.red600, KBrandColors.red600],
    ),
    tabSelectedText: Color(0xFFFFFFFF),
    tabFill: LinearGradient(colors: [Color(0xFF1F1F25), Color(0xFF1F1F25)]),
    tabText: Color(0xFFFFFFFF),
    countdownFill: LinearGradient(
      colors: [Color(0xF216161A), Color(0xF216161A)],
    ),
    countdownBorder: LinearGradient(
      colors: [Color(0xFF34343D), Color(0xFF34343D)],
    ),
    countdownText: Color(0xFFFFFFFF),
    barFill: LinearGradient(colors: [Color(0xFA16161A), Color(0xFA16161A)]),
    barBorder: LinearGradient(colors: [Color(0xFF34343D), Color(0xFF34343D)]),
    barText: Color(0xFFFFFFFF),
    barHint: _gold,
    scrim: [Color(0x4D000000), Color(0xA6000000), Color(0xD9000000)],
  );

  /// «نيون»: near-black cards with a glowing brand-red rim and gold accents.
  static const neon = EventPageTheme(
    id: 'neon',
    cardFill: LinearGradient(colors: [Color(0xE60B0B0D), Color(0xE60B0B0D)]),
    cardBorder: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [KBrandColors.red400, Color(0xFFFF7A82), KBrandColors.red400],
    ),
    cardBorderWidth: 1.6,
    radius: 16,
    glow: [
      BoxShadow(color: Color(0x99FF3B47), blurRadius: 14, spreadRadius: -2),
    ],
    title: Color(0xFFFF7A82),
    titleShadow: [Shadow(color: Color(0xCCFF3B47), blurRadius: 10)],
    accent: LinearGradient(colors: [_gold, _gold]),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFC9C9D1),
    tileFill: Color(0xFF16161A),
    tileBorder: Color(0x66FF3B47),
    chipFill: Color(0xFF1F1F25),
    chipText: Color(0xFFFFFFFF),
    meFill: Color(0xFF1F1013),
    tabSelectedFill: LinearGradient(
      colors: [Color(0x33FF3B47), Color(0x33FF3B47)],
    ),
    tabSelectedBorder: LinearGradient(
      colors: [KBrandColors.red400, KBrandColors.red400],
    ),
    tabSelectedText: Color(0xFFFFFFFF),
    tabFill: LinearGradient(colors: [Color(0xE60B0B0D), Color(0xE60B0B0D)]),
    tabBorder: LinearGradient(colors: [Color(0x80F5C451), Color(0x80F5C451)]),
    tabText: _gold,
    countdownFill: LinearGradient(
      colors: [Color(0xE60B0B0D), Color(0xE60B0B0D)],
    ),
    countdownBorder: LinearGradient(
      colors: [KBrandColors.red400, KBrandColors.red400],
    ),
    countdownText: Color(0xFFFFFFFF),
    barFill: LinearGradient(colors: [Color(0xF20B0B0D), Color(0xF20B0B0D)]),
    barBorder: LinearGradient(
      colors: [KBrandColors.red400, KBrandColors.red400],
    ),
    barText: Color(0xFFFFFFFF),
    barHint: _gold,
    scrim: [Color(0x4D000000), Color(0xA6000000), Color(0xD9000000)],
  );

  /// «أحمر Kabso»: the brand reds (deep shades, so white text keeps
  /// contrast), white rims, a white selected tab.
  static const kabsoRed = EventPageTheme(
    id: 'kabsoRed',
    cardFill: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xF2B80710), Color(0xF28A050C)],
    ),
    cardBorder: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x99FFFFFF), Color(0x26FFFFFF)],
    ),
    cardBorderWidth: 1.2,
    radius: 20,
    title: Color(0xFFFFFFFF),
    titleShadow: [Shadow(color: Color(0x66000000), blurRadius: 3)],
    accent: LinearGradient(colors: [_gold, _gold]),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFFFE2E4),
    tileFill: Color(0xFF6E040A),
    chipFill: Color(0xFF6E040A),
    chipText: Color(0xFFFFFFFF),
    meFill: Color(0xFF6E040A),
    tabSelectedFill: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
    ),
    tabSelectedText: KBrandColors.red600,
    tabFill: LinearGradient(colors: [Color(0xFF6E040A), Color(0xFF6E040A)]),
    tabBorder: LinearGradient(colors: [Color(0x4DFFFFFF), Color(0x4DFFFFFF)]),
    tabText: Color(0xFFFFFFFF),
    countdownFill: LinearGradient(
      colors: [KBrandColors.red600, KBrandColors.red700],
    ),
    countdownBorder: LinearGradient(
      colors: [Color(0x99FFFFFF), Color(0x99FFFFFF)],
    ),
    countdownText: Color(0xFFFFFFFF),
    barFill: LinearGradient(colors: [KBrandColors.red600, KBrandColors.red700]),
    barBorder: LinearGradient(colors: [Color(0x66FFFFFF), Color(0x66FFFFFF)]),
    barText: Color(0xFFFFFFFF),
    barHint: _goldLight,
    scrim: [Color(0x4D000000), Color(0x99000000), Color(0xCC000000)],
  );

  static const List<EventPageTheme> presets = [
    luxuryGold,
    glass,
    darkMinimal,
    neon,
    kabsoRed,
  ];
}

class _EventPageThemeScope extends InheritedWidget {
  const new({required this.theme, required super.child});

  final EventPageTheme theme;

  @override
  bool updateShouldNotify(_EventPageThemeScope old) => old.theme != theme;
}

/// A themed surface: optional backdrop blur, a gradient fill, a gradient rim
/// and an optional glow.
class EventFrame extends StatelessWidget {
  const new({
    required this.child,
    required this.fill,
    super.key,
    this.border,
    this.borderWidth = 1,
    this.radius = 16,
    this.blur = 0,
    this.glow = const [],
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Gradient fill;
  final Gradient? border;
  final double borderWidth;
  final double radius;
  final double blur;
  final List<BoxShadow> glow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(gradient: fill, borderRadius: r),
      child: Padding(padding: padding, child: child),
    );
    if (blur > 0) {
      body = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: body,
        ),
      );
    }
    final border = this.border;
    if (border != null) {
      body = CustomPaint(
        foregroundPainter: _RimPainter(border, borderWidth, radius),
        child: body,
      );
    }
    if (glow.isNotEmpty) {
      body = DecoratedBox(
        decoration: BoxDecoration(borderRadius: r, boxShadow: glow),
        child: body,
      );
    }
    return body;
  }
}

class _RimPainter extends CustomPainter {
  const new(this.gradient, this.width, this.radius);

  final Gradient gradient;
  final double width;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(width / 2),
      Radius.circular((radius - width / 2).clamp(0, radius)),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.gradient != gradient || old.width != width || old.radius != radius;
}

// ---------------------------------------------------------------------------
// The rules button.

enum EventRulesButtonStyle {
  /// 1a. A ribbon tab on the END edge (left in Arabic, right in English).
  edgeRibbonEnd,

  /// 1b. The same tab on the START edge (right in Arabic, as the reference).
  edgeRibbonStart,

  /// 2. A round icon button with a gold ring, top end corner.
  roundIcon,

  /// 3. A gold pill under the countdown.
  goldPill,

  /// 4. A frosted glass chip «القواعد ⓘ», top end corner.
  glassChip,

  /// 5. A vertical side tab (icon + vertical text) on the end edge.
  sideTab,

  /// 6. A text link in the app bar.
  appBarLink,
}

/// The rules glyph. The Kabso icon set has no rules / scroll icon yet; the
/// bundled Material `menu_book` stands in until one is drawn.
const IconData kEventRulesIcon = Icons.menu_book_rounded;

const ui.Color _red600 = KBrandColors.red600;
const ui.Color _red700 = KBrandColors.red700;
const _wineDark = Color(0xFF2A0508);

const _ribbonFill = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [KBrandColors.red500, _red600, _red700],
);

/// 1. The edge ribbon tab: flat against the screen edge, rounded on the
/// inner side, a gold rim, and a small darker fold under it at the edge
/// (as if the ribbon wraps behind the screen).
class EventRulesRibbon extends StatelessWidget {
  const new({required this.onTap, required this.edgeIsLeft, super.key});

  final VoidCallback onTap;

  /// The physical side the tab is attached to.
  final bool edgeIsLeft;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.eventsRules;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _RibbonPainter(edgeIsLeft: edgeIsLeft),
          child: Padding(
            padding: EdgeInsets.only(
              left: edgeIsLeft ? 10 : 18,
              right: edgeIsLeft ? 18 : 10,
              top: 9,
              bottom: 9 + _RibbonPainter.fold,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(kEventRulesIcon, size: 18, color: KBrandColors.gold),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: context.textStyles.label.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const new({required this.edgeIsLeft});

  final bool edgeIsLeft;
  static const double fold = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height - fold;
    final r = h / 2;
    // The tab, drawn for a right edge, mirrored for a left edge.
    canvas.save();
    if (edgeIsLeft) {
      canvas
        ..translate(w, 0)
        ..scale(-1, 1);
    }
    final tab = Path()
      ..moveTo(w, 0)
      ..lineTo(r, 0)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r), clockwise: false)
      ..lineTo(w, h)
      ..close();
    final foldPath = Path()
      ..moveTo(w - 16, h - 2)
      ..lineTo(w, h - 2)
      ..lineTo(w, h + fold)
      ..close();
    canvas
      ..drawShadow(tab, const Color(0xFF000000), 4, false)
      ..drawPath(foldPath, Paint()..color = const Color(0xFF4A0306))
      ..drawPath(
        tab,
        Paint()..shader = _ribbonFill.createShader(Offset.zero & Size(w, h)),
      );
    // The gold rim on the three free sides (not along the edge).
    final rim = Path()
      ..moveTo(w + 1, 1)
      ..lineTo(r, 1)
      ..arcToPoint(
        Offset(r, h - 1),
        radius: Radius.circular(r - 1),
        clockwise: false,
      )
      ..lineTo(w + 1, h - 1);
    canvas
      ..drawPath(
        rim,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE7A3), KBrandColors.gold, Color(0xFFB7811A)],
          ).createShader(Offset.zero & Size(w, h))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.edgeIsLeft != edgeIsLeft;
}

/// 2. A round icon button: a wine disc, a gold ring, the rules glyph, and
/// the word under it.
class EventRulesRoundButton extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.eventsRules;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFFFFE7A3),
                    KBrandColors.gold,
                    Color(0xFFB7811A),
                    KBrandColors.gold,
                    Color(0xFFFFE7A3),
                  ],
                ),
                boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 6)],
              ),
              padding: const EdgeInsets.all(2.5),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_red600, _wineDark],
                    radius: 0.9,
                  ),
                ),
                child: Center(
                  child: Icon(
                    kEventRulesIcon,
                    size: 21,
                    color: KBrandColors.gold,
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

/// 3. A gold pill (dark wine text) under the countdown.
class EventRulesGoldPill extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.eventsRules;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.pill),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE7A3), KBrandColors.gold, Color(0xFFB7811A)],
            ),
            border: Border.all(color: const Color(0xFF8A5A10)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(kEventRulesIcon, size: 18, color: _wineDark),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.textStyles.label.copyWith(
                  color: _wineDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4. A frosted glass chip «القواعد ⓘ».
class EventRulesGlassChip extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.eventsRules;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KRadius.pill),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x52000000),
                borderRadius: BorderRadius.circular(KRadius.pill),
                border: Border.all(color: const Color(0x66FFFFFF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: context.textStyles.label.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w700,
                      shadows: KLiveColors.glassShadow,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: Color(0xFFFFFFFF),
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

/// 5. A vertical side tab: the glyph on top, the word turned along the edge.
class EventRulesSideTab extends StatelessWidget {
  const new({required this.onTap, required this.edgeIsLeft, super.key});

  final VoidCallback onTap;
  final bool edgeIsLeft;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.eventsRules;
    const r = Radius.circular(14);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_red600, _red700],
            ),
            borderRadius: edgeIsLeft
                ? const BorderRadius.only(topRight: r, bottomRight: r)
                : const BorderRadius.only(topLeft: r, bottomLeft: r),
            border: Border(
              top: const BorderSide(color: KBrandColors.gold, width: 1.5),
              bottom: const BorderSide(color: KBrandColors.gold, width: 1.5),
              left: edgeIsLeft
                  ? BorderSide.none
                  : const BorderSide(color: KBrandColors.gold, width: 1.5),
              right: edgeIsLeft
                  ? const BorderSide(color: KBrandColors.gold, width: 1.5)
                  : BorderSide.none,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x80000000), blurRadius: 8),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(kEventRulesIcon, size: 18, color: KBrandColors.gold),
              const SizedBox(height: 6),
              RotatedBox(
                // Reads upward on a left edge, downward on a right edge.
                quarterTurns: edgeIsLeft ? 3 : 1,
                child: Text(
                  label,
                  style: context.textStyles.label.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 6. A text link in the app bar.
class EventRulesAppBarLink extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.eventsRules;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
          alignment: Alignment.center,
          child: Text(
            label,
            style: context.textStyles.label.copyWith(
              color: KBrandColors.gold,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: KBrandColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}

/// The rules in a bottom sheet, styled as the ribbon (wine, gold rim, gold
/// numbered markers).
Future<void> showEventRulesSheet(
  BuildContext context, {
  required List<String> lines,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0x00000000),
  isScrollControlled: true,
  builder: (sheet) => EventRulesSheet(lines: lines),
);

class EventRulesSheet extends StatelessWidget {
  const new({required this.lines, super.key});

  final List<String> lines;

  static const sheetKey = Key('event.rulesSheet');

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    const top = Radius.circular(KRadius.xl);
    return Container(
      key: sheetKey,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: top),
        gradient: LinearGradient(
          colors: [Color(0xFFFFE7A3), KBrandColors.gold, Color(0xFFB7811A)],
        ),
      ),
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: top),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A0A10), _wineDark],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x99F5C451),
                      borderRadius: BorderRadius.circular(KRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                Row(
                  children: [
                    const Icon(
                      kEventRulesIcon,
                      size: 22,
                      color: KBrandColors.gold,
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Text(
                        context.l10n.eventsRules,
                        style: t.title.copyWith(
                          color: KBrandColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        customBorder: const CircleBorder(),
                        child: const SizedBox.square(
                          dimension: 44,
                          child: Icon(
                            Icons.close_rounded,
                            color: Color(0xFFF1DDB0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x00F5C451),
                        KBrandColors.gold,
                        Color(0x00F5C451),
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFE7A3), Color(0xFFB7811A)],
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: t.caption.copyWith(
                              color: _wineDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: Text(
                            lines[i],
                            style: t.body.copyWith(
                              color: const Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
