import 'dart:math' as math;

import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// D216 (owner: «رسائل انقطاع البث … حاول التقيد بهويتنا»): the one card
/// every interrupted-live state uses — the host away, reconnecting, the
/// video that could not connect, the live that ended, a room that cannot
/// open, a camera that is off.
///
/// D221 (owner's design «اقتراح عند انقطاع البث وانتهائه», measured in
/// docs/design/d221-live-interruption-spec.md; the owner then dropped the
/// glass card: the content stands on the screen's dark background): the
/// host's picture (or the state's icon) in a glowing red ring with a faint
/// outer ring and red sound-wave bars on both sides; a red reason badge on
/// the picture; a red status pill over the bottom of the ring; the host's
/// name in gold (a crown only when [crowned]); a large bold title, one grey
/// line and full-width buttons ([KLiveInterruptionButton]).
///
/// [busy] states (waiting for the host, reconnecting) move the sound waves
/// and turn a bright arc on the ring; with reduced motion (or [animate] off)
/// everything holds still. Presentation only: the caller decides when each
/// state shows.
class KLiveInterruption extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.icon,
    this.leading,
    this.badgeIcon,
    this.eyebrow,
    this.crowned = false,
    this.status,
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

  /// A picture in the emblem (the host's avatar, see [KLiveHostPicture]),
  /// drawn in a circle.
  final Widget? leading;

  /// A red badge on the picture's lower centre saying why.
  final IconData? badgeIcon;

  /// A short line over the title (the host's name), in gold.
  final String? eyebrow;

  /// A crown before [eyebrow]: only for a status the app really knows
  /// (D221: no production caller has one yet, so it is off there).
  final bool crowned;

  /// The state in a red pill over the bottom of the ring («انتهى البث»).
  final String? status;
  final String title;
  final String? message;

  /// A small last line (an error id).
  final String? detail;

  /// Waiting for something to come back: the waves move, the arc turns.
  final bool busy;

  /// Buttons under the text, one per line (only actions that exist).
  final List<Widget> actions;

  /// The full spacing of the (former) card; off where the emblem stands on
  /// its own (a video tile). D221: no card is drawn either way.
  final bool framed;

  /// A smaller emblem and the title only (a camera-off tile).
  final bool compact;

  /// Screen readers hear the title when it appears.
  final bool liveRegion;

  /// Off in widget tests (the waves and the arc move forever; frames would
  /// never settle — `test/flutter_test_config.dart`).
  static bool animate = true;

  /// The ring's outer diameter (D221: 264 px of the 976 px card → 86 dp).
  static const double emblem = 86;
  static const double emblemCompact = 52;

  /// The [leading] picture's diameter (inside the ring).
  static const double picture = 80;
  static const double pictureCompact = 46;
  static const double maxWidth = 320;

  /// The emblem block: the faint outer ring (107 dp) from 12 dp under the
  /// card's top edge to the bottom of the status pill.
  static const double _outerRing = 107;
  static const double _pillCentre = 91;
  static const double _pillHeight = 22;
  static const double _block = _pillCentre + _pillHeight / 2;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final text = context.textStyles;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final eyebrow = this.eyebrow;
    final status = this.status;
    final message = this.message;
    final detail = this.detail;
    final emblem = _Emblem(
      size: compact ? emblemCompact : KLiveInterruption.emblem,
      icon: icon,
      leading: leading,
      badgeIcon: badgeIcon,
      busy: busy,
      waves: !compact,
    );
    final titleText = Semantics(
      header: !compact,
      liveRegion: liveRegion,
      child: Text(
        title,
        textAlign: TextAlign.center,
        textScaler: scaler,
        style: (compact ? text.bodyStrong : text.headline).copyWith(
          color: p.textPrimary,
          fontSize: compact ? null : 22,
          height: compact ? null : 1.35,
          shadows: KLiveColors.glassShadow,
        ),
      ),
    );
    if (compact) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: emblemCompact + 8, child: emblem),
              const SizedBox(height: KSpacing.sm),
              titleText,
            ],
          ),
        ),
      );
    }
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _block,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _outerRing,
                child: emblem,
              ),
              if (status != null)
                Positioned(
                  top: _pillCentre - _pillHeight / 2,
                  child: _StatusPill(label: status, scaler: scaler),
                ),
            ],
          ),
        ),
        SizedBox(height: status == null ? KSpacing.sm : 11),
        if (eyebrow != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (crowned) ...[
                const AppIcon(
                  AppIcons.crownFilled,
                  key: Key('live.interruption.crown'),
                  size: 15,
                  color: KBrandColors.gold,
                ),
                const SizedBox(width: KSpacing.sm),
              ],
              Flexible(
                child: Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textScaler: scaler,
                  style: text.bodyStrong.copyWith(
                    color: KBrandColors.gold,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xxs),
        ],
        titleText,
        if (message != null) ...[
          const SizedBox(height: KSpacing.xxs),
          Text(
            message,
            textAlign: TextAlign.center,
            textScaler: scaler,
            style: text.body.copyWith(
              color: p.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
        if (detail != null) ...[
          const SizedBox(height: KSpacing.xs),
          Text(
            detail,
            textAlign: TextAlign.center,
            textScaler: scaler,
            style: text.caption.copyWith(color: p.textTertiary),
          ),
        ],
        if (actions.isNotEmpty) ...[
          // 13 dp to the first button's face (its 48 dp target is 4 dp
          // taller on each side).
          const SizedBox(height: 9),
          for (final action in actions)
            SizedBox(width: double.infinity, child: action),
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
    // D221 (owner: «حاول ازالة بطاقة الكريستال هذه»): no card — the
    // content stands on the screen's own dark background, with the card's
    // spacing kept.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          12,
          28,
          actions.isEmpty ? KSpacing.xl + KSpacing.xs : 23,
        ),
        child: content,
      ),
    );
  }
}

/// The host's picture for the emblem: the photo, or (no photo, or it fails
/// to load) a neutral silhouette.
class KLiveHostPicture extends StatelessWidget {
  const new({required this.size, super.key, this.image, this.imageUrl});

  final double size;
  final ImageProvider? image;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final provider =
        image ?? (url == null || url.isEmpty ? null : NetworkImage(url));
    final silhouette = SizedBox.square(
      key: const Key('live.interruption.silhouette'),
      dimension: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            colors: [Color(0xFF2A1A26), Color(0xFF170C15)],
          ),
        ),
        child: Align(
          alignment: const Alignment(0, 0.9),
          child: Icon(
            Icons.person_rounded,
            size: size * 0.92,
            color: const Color(0x66C9B4C2),
          ),
        ),
      ),
    );
    if (provider == null) return silhouette;
    return ClipOval(
      child: Image(
        image: provider,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => silhouette,
      ),
    );
  }
}

/// A full-width button of the card: [primary] is the red gradient
/// («متابعة»), otherwise the dark outline. The face is 40 dp (primary) or
/// 36 dp tall as measured; the tap target is always 48 dp.
class KLiveInterruptionButton extends StatefulWidget {
  const new({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
    this.primary = true,
  });

  final String label;
  final IconData icon;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final bool primary;

  static const double primaryFace = 40;
  static const double secondaryFace = 36;
  static const double target = 48;

  @override
  State<KLiveInterruptionButton> createState() =>
      _KLiveInterruptionButtonState();
}

class _KLiveInterruptionButtonState extends State<KLiveInterruptionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final primary = widget.primary;
    final enabled = widget.onPressed != null;
    final face = primary
        ? KLiveInterruptionButton.primaryFace
        : KLiveInterruptionButton.secondaryFace;
    final radius = BorderRadius.circular(KRadius.lg);
    final style = context.textStyles.bodyStrong.copyWith(
      color: p.textPrimary,
      fontSize: primary ? 16 : 15,
      fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
      height: 1.2,
    );
    final decoration = primary
        ? BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                KBrandColors.red400,
                KBrandColors.red500,
                Color(0xFF95010E),
              ],
              stops: [0, 0.4, 1],
            ),
            border: Border.all(color: const Color(0x59FFB4C0)),
            boxShadow: const [
              BoxShadow(color: Color(0x4DE50914), blurRadius: 14),
            ],
          )
        : BoxDecoration(
            borderRadius: radius,
            color: const Color(0xFF241C26),
            border: Border.all(color: const Color(0x52FFFFFF)),
          );
    final label = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(widget.icon, size: primary ? 20 : 19, color: p.textPrimary),
        SizedBox(width: primary ? 13 : 11),
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
            style: style,
          ),
        ),
      ],
    );
    // Its own transparent sheet: the card can sit outside any Material.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (v) => setState(() => _down = v),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          borderRadius: radius,
          child: SizedBox(
            height: KLiveInterruptionButton.target,
            child: Center(
              child: AnimatedOpacity(
                opacity: !enabled ? 0.5 : (_down ? 0.8 : 1),
                duration: const Duration(milliseconds: 90),
                child: Container(
                  height: face,
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
                  decoration: decoration,
                  child: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «• انتهى البث»: the state in a red pill.
class _StatusPill extends StatelessWidget {
  const new({required this.label, required this.scaler});

  final String label;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    return Container(
      key: const Key('live.interruption.status'),
      constraints: const BoxConstraints(
        minHeight: KLiveInterruption._pillHeight,
        maxWidth: 220,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7122E), Color(0xFFCD0108)],
        ),
        border: Border.all(color: const Color(0x66FFB4C0), width: 0.8),
        boxShadow: const [BoxShadow(color: Color(0x66E50914), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler.clamp(maxScaleFactor: 1.15),
              style: context.textStyles.label.copyWith(
                color: p.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The round emblem: the faint outer ring, the sound waves, the glowing
/// brand-red ring around the picture or the icon, and the reason badge.
/// Laid out in the box it is given, centred on its middle.
class _Emblem extends StatefulWidget {
  const new({
    required this.size,
    required this.icon,
    required this.leading,
    required this.badgeIcon,
    required this.busy,
    required this.waves,
  });

  /// The ring's outer diameter.
  final double size;
  final IconData? icon;
  final Widget? leading;
  final IconData? badgeIcon;
  final bool busy;
  final bool waves;

  @override
  State<_Emblem> createState() => _EmblemState();
}

class _EmblemState extends State<_Emblem> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Emblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final moving =
        widget.busy &&
        KLiveInterruption.animate &&
        !MediaQuery.disableAnimationsOf(context);
    if (moving && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!moving && _clock.isAnimating) {
      _clock
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final leading = widget.leading;
    final badgeIcon = widget.badgeIcon;
    final compact = !widget.waves;
    // The ring is 2 dp (1.5 compact) with the picture 1 dp inside it.
    final disc = compact
        ? KLiveInterruption.pictureCompact
        : KLiveInterruption.picture;
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
                center: Alignment(0, -0.2),
                colors: [Color(0xFF3A1222), Color(0xFF1A0B16)],
              ),
            ),
            child: Icon(
              widget.icon,
              size: disc * 0.42,
              color: KPalette.dark.textPrimary,
            ),
          );
    final badge = compact ? 18.0 : 26.0;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _HaloPainter(
            clock: _clock,
            ring: size,
            busy: widget.busy,
            waves: widget.waves,
          ),
          child: Center(
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  inner,
                  if (badgeIcon != null)
                    Positioned(
                      // The badge sits on the picture's lower centre
                      // (measured 13 dp under the ring's centre).
                      top: size / 2 + (compact ? 10 : 13) - badge / 2,
                      child: Container(
                        key: const Key('live.interruption.badge'),
                        width: badge,
                        height: badge,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF0303E), Color(0xFFD50A12)],
                          ),
                          border: Border.all(
                            color: const Color(0x80FFB4C0),
                            width: 0.8,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x80E50914), blurRadius: 8),
                          ],
                        ),
                        child: Icon(
                          badgeIcon,
                          size: badge * 0.62,
                          color: KPalette.dark.onPrimary,
                        ),
                      ),
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

/// The halo around the picture, drawn on the emblem's whole box: the faint
/// outer ring, the red glow, the ring, the sound-wave bars on both sides
/// (symmetric, fading outwards) and, while busy, the turning arc.
class _HaloPainter extends CustomPainter {
  new({
    required this.clock,
    required this.ring,
    required this.busy,
    required this.waves,
  }) : super(repaint: clock);

  final Animation<double> clock;

  /// The ring's outer diameter.
  final double ring;
  final bool busy;
  final bool waves;

  /// The bars from the ring outwards (D221, measured on the owner's card,
  /// dp): distance from the centre, height, opacity.
  static const List<(double, double, double)> _bars = [
    (54, 3, 0.5),
    (59.5, 5, 0.75),
    (65, 9, 0.9),
    (70.5, 17, 0.85),
    (76, 24, 1),
    (81.5, 15, 0.6),
    (87, 7, 0.4),
    (92.5, 4, 0.28),
    (98, 2.5, 0.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = ring / 2;
    final t = clock.value;
    if (waves) {
      // The faint outer ring.
      canvas.drawCircle(
        c,
        KLiveInterruption._outerRing / 2 - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x4DE50914),
      );
      final bar = Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (final (i, (d, h, a)) in _bars.indexed) {
        // While busy each bar breathes (0.45 … 1 of its height), out of
        // phase with its neighbours; still otherwise.
        final k = busy
            ? 0.725 + 0.275 * math.sin(2 * math.pi * t + i * 0.9)
            : 1;
        final half = math.max<double>(1, h * k / 2);
        bar.color = KBrandColors.red500.withValues(alpha: a);
        for (final side in const <double>[-1, 1]) {
          final x = c.dx + side * d;
          canvas.drawLine(Offset(x, c.dy - half), Offset(x, c.dy + half), bar);
        }
      }
    }
    // The glow behind and around the ring.
    canvas
      ..drawCircle(
        c,
        r,
        Paint()
          ..color = KBrandColors.red500.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawCircle(
        c,
        r - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = waves ? 2 : 1.5
          ..shader = const SweepGradient(
            colors: [
              KBrandColors.red500,
              KBrandColors.red400,
              Color(0xFFFF6E78),
              KBrandColors.red400,
              KBrandColors.red500,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    if (!busy) return;
    final rect = Rect.fromCircle(center: c, radius: r - 1);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(t * 2 * math.pi)
      ..translate(-c.dx, -c.dy)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 0.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = waves ? 3 : 2.5
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: math.pi * 0.1,
            colors: [Color(0x00FFFFFF), Color(0xFFFFD6DA)],
          ).createShader(rect),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) =>
      oldDelegate.busy != busy ||
      oldDelegate.ring != ring ||
      oldDelegate.waves != waves;
}
