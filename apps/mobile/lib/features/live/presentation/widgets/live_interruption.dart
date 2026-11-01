import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// D216 (owner: «رسائل انقطاع البث … حاول التقيد بهويتنا»): the one card
/// every interrupted-live state uses — the host away, reconnecting, the
/// video that could not connect, the live that ended, a room that cannot
/// open, a camera that is off. Kabso's live glass (a blurred dark veil with
/// a thin bright edge), a round emblem with the brand-red ring (the host's
/// picture with a small reason badge, or an icon), a clear title, one short
/// line and only the real actions.
///
/// [busy] states (waiting for the host, reconnecting) turn a soft red arc
/// around the emblem; with reduced motion (or [animate] off) the arc holds
/// still. Presentation only: the caller decides when each state shows.
class KLiveInterruption extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.icon,
    this.leading,
    this.badgeIcon,
    this.eyebrow,
    this.message,
    this.detail,
    this.busy = false,
    this.actions = const [],
    this.framed = true,
    this.compact = false,
    this.liveRegion = true,
  }) : assert(icon != null || leading != null, 'an icon or a picture');

  /// The emblem's icon (when there is no [leading] picture).
  final IconData? icon;

  /// A picture in the emblem (the host's avatar), drawn in a circle.
  final Widget? leading;

  /// A small badge on the picture's lower end corner saying why.
  final IconData? badgeIcon;

  /// A short line over the title (the host's name).
  final String? eyebrow;
  final String title;
  final String? message;

  /// A small last line (an error id).
  final String? detail;

  /// Waiting for something to come back: the arc turns.
  final bool busy;

  /// Buttons under the text, one per line (only actions that exist).
  final List<Widget> actions;

  /// The glass card around it; off where the emblem stands on its own (a
  /// video tile).
  final bool framed;

  /// A smaller emblem and the title only (a camera-off tile).
  final bool compact;

  /// Screen readers hear the title when it appears.
  final bool liveRegion;

  /// Off in widget tests (the arc turns forever; frames would never
  /// settle — `test/flutter_test_config.dart`).
  static bool animate = true;

  static const double emblem = 88;
  static const double emblemCompact = 68;

  /// The [leading] picture's diameter (the ring and arc sit outside it).
  static const double picture = emblem - _ringSpace;
  static const double pictureCompact = emblemCompact - _ringSpace;
  static const double _ringSpace = 24;
  static const double maxWidth = 320;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final text = context.textStyles;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final eyebrow = this.eyebrow;
    final message = this.message;
    final detail = this.detail;
    final size = compact ? emblemCompact : emblem;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Emblem(
          size: size,
          icon: icon,
          leading: leading,
          badgeIcon: badgeIcon,
          busy: busy,
        ),
        SizedBox(height: compact ? KSpacing.sm : KSpacing.md),
        if (eyebrow != null) ...[
          Text(
            eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textScaler: scaler,
            style: text.label.copyWith(color: KBrandColors.gold),
          ),
          const SizedBox(height: KSpacing.xxs),
        ],
        Semantics(
          header: !compact,
          liveRegion: liveRegion,
          child: Text(
            title,
            textAlign: TextAlign.center,
            textScaler: scaler,
            style: (compact ? text.bodyStrong : text.title).copyWith(
              color: p.textPrimary,
              shadows: framed ? null : KLiveColors.glassShadow,
            ),
          ),
        ),
        if (message != null && !compact) ...[
          const SizedBox(height: KSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            textScaler: scaler,
            style: text.body.copyWith(color: p.textSecondary, fontSize: 14),
          ),
        ],
        if (detail != null && !compact) ...[
          const SizedBox(height: KSpacing.sm),
          Text(
            detail,
            textAlign: TextAlign.center,
            textScaler: scaler,
            style: text.caption.copyWith(color: p.textTertiary),
          ),
        ],
        if (actions.isNotEmpty && !compact) ...[
          const SizedBox(height: KSpacing.lg),
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(height: KSpacing.sm),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ],
    );
    if (!framed) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: content,
        ),
      );
    }
    final shape = BorderRadius.circular(KRadius.xl);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB31F1F25), Color(0xD90B0B0D)],
                ),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.xl,
                  KSpacing.xl,
                  KSpacing.xl,
                  KSpacing.lg + KSpacing.xs,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round emblem: a brand-red ring around the picture or the icon, the
/// reason badge, and the turning arc while [busy].
class _Emblem extends StatelessWidget {
  const new({
    required this.size,
    required this.icon,
    required this.leading,
    required this.badgeIcon,
    required this.busy,
  });

  final double size;
  final IconData? icon;
  final Widget? leading;
  final IconData? badgeIcon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final badgeIcon = this.badgeIcon;
    // The ring sits 3 dp outside the disc; the arc 4 dp outside the ring.
    final disc = size - KLiveInterruption._ringSpace;
    final inner = leading != null
        ? ClipOval(
            child: SizedBox.square(dimension: disc, child: leading),
          )
        : Container(
            width: disc,
            height: disc,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x59E50914), Color(0x1A8A050C)],
              ),
            ),
            child: Icon(
              icon,
              size: disc * 0.46,
              color: KPalette.dark.textPrimary,
            ),
          );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _Arc(busy: busy)),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: KBrandColors.red500.withValues(alpha: 0.85),
                  width: KMetrics.thinStroke,
                ),
              ),
              child: inner,
            ),
            if (badgeIcon != null)
              PositionedDirectional(
                end: 2,
                bottom: 2,
                child: Container(
                  width: size * 0.34,
                  height: size * 0.34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [KBrandColors.red400, KBrandColors.red600],
                    ),
                    border: Border.all(
                      color: KPalette.dark.background,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    badgeIcon,
                    size: size * 0.18,
                    color: KPalette.dark.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The soft halo around the emblem; while busy, a red arc that turns once
/// every 1.4 s (still with reduced motion).
class _Arc extends StatefulWidget {
  const new({required this.busy});

  final bool busy;

  @override
  State<_Arc> createState() => _ArcState();
}

class _ArcState extends State<_Arc> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Arc oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final moving =
        widget.busy &&
        KLiveInterruption.animate &&
        !MediaQuery.disableAnimationsOf(context);
    if (moving && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!moving && _turn.isAnimating) {
      _turn
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _ArcPainter(turn: _turn, busy: widget.busy),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  new({required this.turn, required this.busy}) : super(repaint: turn);

  final Animation<double> turn;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    // The halo: a soft red glow behind the ring.
    canvas.drawCircle(
      center,
      radius - 4,
      Paint()
        ..color = KBrandColors.red500.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    if (!busy) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0x1FFFFFFF),
      )
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(turn.value * 2 * math.pi)
      ..translate(-center.dx, -center.dy)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 0.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: math.pi * 0.1,
            colors: [Color(0x00FF3B47), KBrandColors.red400],
          ).createShader(rect),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.busy != busy;
}
