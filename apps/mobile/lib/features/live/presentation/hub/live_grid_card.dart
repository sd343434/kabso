import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the live hub grid (D124).
abstract final class KLiveGrid {
  /// Side padding of the grid and the banner.
  static const double inset = 16;

  /// Gap between cards (both axes) and around the banner.
  static const double gap = 8;
  static const double radius = KRadius.md;

  /// Portrait cards, width : height.
  static const double cardAspect = 0.75;

  /// The banner sits after this many cards.
  static const int bannerAfter = 4;

  /// Cards' overlay text grows with the text scale up to this factor (the
  /// card has a fixed size; its screen-reader label carries everything).
  static const double maxTextScale = 1.3;

  /// Skeleton cards while the first page loads.
  static const int skeletonCount = 6;
}

/// One live room in the live hub's 2-column grid (D124).
///
/// - Picture: the live cover (CP-015); else the host's photo filling the
///   card; else the host's initial on the brand gradient. A picture that
///   fails to load falls back the same way, with no error text (VG-13).
/// - Top start: the animated live mark ([KLiveEqualizer]) and the room type
///   (Audio, PK or Video). Top end: the viewer count with a person icon, or
///   "New" below 1 viewer (VG-11: a count is never invented).
/// - Bottom, over a scrim: the title (1 line), then the host's name and the
///   category pill when the room has one.
/// - Press: scales to 0.98 (instant with reduce motion).
///
/// Announced as "{host}, live, {n viewers | New}, {title}[, {type}]
/// [, {category}]".
class KLiveGridCard extends StatelessWidget {
  const new({required this.room, super.key, this.onTap});

  final LiveRoomCardData room;
  final VoidCallback? onTap;

  static const typeKey = Key('liveGrid.type');
  static const viewersKey = Key('liveGrid.viewers');
  static const categoryKey = Key('liveGrid.category');
  static const initialKey = Key('liveGrid.initial');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    const shadows = [
      Shadow(color: Color(0x80000000), blurRadius: 4, offset: Offset(0, 1)),
    ];
    final isNew = room.viewerCount < 1;
    final type = room.isAudio
        ? l10n.liveGridAudio
        : room.inPk
        ? l10n.pkBadge
        : l10n.liveGridVideo;
    final base = l10n.liveCardSemantics(
      room.hostName,
      isNew
          ? l10n.liveCardNew
          : l10n.liveViewers(
              room.viewerCount,
              KFormat.grouped(room.viewerCount),
            ),
      room.title,
    );
    final withType = l10n.liveCardSemanticsMode(base, type);
    final category = room.categoryName;
    final hasCategory = category != null && category.isNotEmpty;
    final semantics = hasCategory
        ? l10n.liveCardSemanticsCategory(withType, category)
        : withType;
    final fallback = _Fallback(room: room);
    final cover = room.cover;

    return Semantics(
      button: onTap != null,
      label: semantics,
      container: true,
      child: ExcludeSemantics(
        child: _Frame(
          onTap: onTap,
          children: [
            if (cover == null)
              fallback
            else
              Image(
                image: cover,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              ),
            const _Scrims(),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: KLiveGrid.maxTextScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PositionedDirectional(
                    top: KSpacing.sm,
                    start: KSpacing.sm,
                    end: KSpacing.sm,
                    child: Row(
                      children: [
                        KLiveEqualizer(color: white),
                        const SizedBox(width: KSpacing.xs),
                        Flexible(
                          child: Text(
                            type,
                            key: typeKey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              color: white,
                              fontWeight: FontWeight.w700,
                              shadows: shadows,
                            ),
                          ),
                        ),
                        const SizedBox(width: KSpacing.xs),
                        Row(
                          key: viewersKey,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isNew) ...[
                              Icon(
                                Icons.person_outline_rounded,
                                size: KMetrics.iconXs + 2,
                                color: white,
                                shadows: shadows,
                              ),
                              const SizedBox(width: KSpacing.xxs),
                            ],
                            Text(
                              isNew
                                  ? l10n.liveCardNew
                                  : KFormat.compact(room.viewerCount, l10n),
                              maxLines: 1,
                              style: t.caption.copyWith(
                                color: white,
                                fontWeight: FontWeight.w700,
                                shadows: shadows,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    start: KSpacing.sm,
                    end: KSpacing.sm,
                    bottom: KSpacing.sm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          room.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            color: white,
                            shadows: shadows,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xxs),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                room.hostName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption.copyWith(
                                  color: white.withValues(alpha: 0.85),
                                  shadows: shadows,
                                ),
                              ),
                            ),
                            if (hasCategory) ...[
                              const SizedBox(width: KSpacing.xs),
                              Flexible(
                                child: _CategoryPill(
                                  key: categoryKey,
                                  name: category,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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

/// Loading state with the card's anatomy.
class KLiveGridCardSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const _Frame(
    skeleton: true,
    children: [
      PositionedDirectional(
        top: KSpacing.sm,
        start: KSpacing.sm,
        child: KSkeleton(width: 48, height: 14, radius: KRadius.pill),
      ),
      PositionedDirectional(
        top: KSpacing.sm,
        end: KSpacing.sm,
        child: KSkeleton(width: 32, height: 14, radius: KRadius.pill),
      ),
      PositionedDirectional(
        start: KSpacing.sm,
        end: KSpacing.xxxl,
        bottom: KSpacing.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            KSkeleton(width: double.infinity, height: KSpacing.md),
            SizedBox(height: KSpacing.xs),
            KSkeleton(width: 64, height: KSpacing.sm),
          ],
        ),
      ),
    ],
  );
}

/// The small animated "live" mark: three bars rising and falling. Static
/// with reduce motion (and in widget tests, through [animate]).
class KLiveEqualizer extends StatefulWidget {
  const new({required this.color, super.key, this.size = 12});

  final Color color;
  final double size;

  /// Off in widget tests and goldens (a repeating animation never settles).
  static bool animate = true;

  @override
  State<KLiveEqualizer> createState() => _KLiveEqualizerState();
}

class _KLiveEqualizerState extends State<KLiveEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        !KLiveEqualizer.animate || MediaQuery.disableAnimationsOf(context);
    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => CustomPaint(
        painter: _EqualizerPainter(
          phase: _controller.value,
          color: widget.color,
        ),
      ),
    ),
  );
}

class _EqualizerPainter extends CustomPainter {
  new({required this.phase, required this.color});

  final double phase;
  final Color color;

  /// Resting heights (fractions of the box) when not animating.
  static const _rest = [0.55, 1.0, 0.75];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bar = size.width / 5;
    for (var i = 0; i < 3; i++) {
      final wave = math.sin((phase + i / 3) * 2 * math.pi);
      final h = phase == 0
          ? _rest[i]
          : (0.35 + 0.65 * (0.5 + 0.5 * wave)).clamp(0.3, 1.0);
      final height = size.height * h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 2 * bar, size.height - height, bar, height),
          Radius.circular(bar / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) =>
      old.phase != phase || old.color != color;
}

class _CategoryPill extends StatelessWidget {
  const new({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x59000000),
      borderRadius: BorderRadius.circular(KRadius.pill),
      border: Border.all(color: const Color(0x40FFFFFF), width: 0.5),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KSpacing.xs + 2,
        vertical: 1,
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.caption.copyWith(
          color: KPalette.dark.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// A soft scrim at the top (badges) and a stronger one at the bottom
/// (title and host), so white text reads over any picture.
class _Scrims extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.22, 0.5, 1],
          colors: [
            Color(0x59000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xB3000000),
          ],
        ),
      ),
    ),
  );
}

/// No (working) cover: the host's photo filling the card, else their
/// initial on the brand gradient.
class _Fallback extends StatelessWidget {
  const new({required this.room});

  final LiveRoomCardData room;

  @override
  Widget build(BuildContext context) {
    final initial = _Initial(name: room.hostName);
    final avatar = room.hostAvatar;
    if (avatar == null) return initial;
    return Image(
      image: avatar,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => initial,
    );
  }
}

class _Initial extends StatelessWidget {
  const new({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: KBrandColors.gradientLive,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: const Alignment(0, -0.15),
          child: Text(
            letter,
            key: KLiveGridCard.initialKey,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: KPalette.dark.textPrimary,
              fontSize: box.maxWidth * 0.42,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Frame extends StatefulWidget {
  const new({required this.children, this.onTap, this.skeleton = false});

  final List<Widget> children;
  final VoidCallback? onTap;
  final bool skeleton;

  @override
  State<_Frame> createState() => _FrameState();
}

class _FrameState extends State<_Frame> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return AnimatedScale(
      scale: _pressed ? KMetrics.cardPressedScale : 1,
      duration: KMotion.of(context, KMotion.fast),
      curve: KMotion.standard,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KLiveGrid.radius),
        child: Material(
          color: widget.skeleton
              ? context.palette.surface
              : context.palette.surfaceRaised,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ...widget.children,
              if (onTap != null)
                InkWell(onTap: onTap, onHighlightChanged: _press),
            ],
          ),
        ),
      ),
    );
  }
}
