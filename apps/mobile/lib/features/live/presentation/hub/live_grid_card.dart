import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the live hub grid (D124; D131 measured on ref 165 at
/// 393 pt: cards 423 × 473 px, 30 px from the sides, 17 px apart across and
/// 14 px down).
abstract final class KLiveGrid {
  /// Side padding of the grid and the banner (30 px = 12.8 pt; 13 keeps
  /// the banner's page width whole on a 360 pt screen).
  static const double inset = 13;

  /// Gap between cards across (17 px = 7.2 pt) and around the banner.
  static const double gap = 7.2;

  /// Gap between card rows (14 px = 6 pt).
  static const double rowGap = 6;

  /// Corner radius (≈ 10–12 px; E).
  static const double radius = 5;

  /// Cards, width : height (180 × 201.4 pt).
  static const double cardAspect = 0.894;

  /// The live mark's teal (sampled `#18D6C3`).
  static const Color liveMark = Color(0xFF18D6C3);

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
/// - Top start: the animated live mark ([KLiveEqualizer], teal) and, for
///   PK and multi-guest lives, the room type (ref 165 labels only those).
///   Top end: the viewer count with a person icon, or "New" below 1 viewer
///   (VG-11: a count is never invented).
/// - Bottom, over a scrim: the title (1 line, bold). The host's name and
///   the category are announced, not drawn (ref 165).
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
  static const initialKey = Key('liveGrid.initial');

  /// D154b: the «مميز» label of a live with a running traffic card.
  static const featuredKey = Key('liveGrid.featured');

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
        : room.isMulti
        ? l10n.goLiveModeMulti
        : l10n.liveGridVideo;
    final showType = room.inPk || room.isMulti;
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
    final described = hasCategory
        ? l10n.liveCardSemanticsCategory(withType, category)
        : withType;
    final semantics = room.featured
        ? '${l10n.liveBoostFeatured}, $described'
        : described;

    return Semantics(
      button: onTap != null,
      label: semantics,
      container: true,
      child: ExcludeSemantics(
        child: _Frame(
          onTap: onTap,
          children: [
            KLiveRoomPicture(room: room),
            const _Scrims(),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: KLiveGrid.maxTextScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Ref 165: the mark 10.6 pt in, the row centred 15 pt
                  // down; the count's end 9.4 pt in.
                  PositionedDirectional(
                    top: 6,
                    start: 10,
                    end: 9,
                    child: SizedBox(
                      height: 18,
                      child: Row(
                        children: [
                          const KLiveEqualizer(
                            color: KLiveGrid.liveMark,
                            size: 10,
                          ),
                          if (showType) ...[
                            const SizedBox(width: KSpacing.xs),
                            Flexible(
                              child: Text(
                                type,
                                key: typeKey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption.copyWith(
                                  color: white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  shadows: shadows,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Row(
                            key: viewersKey,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isNew) ...[
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: shadows,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // D154b: «مميز» over the title (a running traffic card).
                  if (room.featured)
                    PositionedDirectional(
                      start: 8.5,
                      bottom: 28,
                      child: Container(
                        key: featuredKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD36E), Color(0xFFF2A93B)],
                          ),
                          borderRadius: BorderRadius.circular(KRadius.pill),
                        ),
                        child: Text(
                          l10n.liveBoostFeatured,
                          maxLines: 1,
                          style: t.caption.copyWith(
                            color: const Color(0xFF3B2200),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  // Ref 165: the title 8.5 pt in, its baseline 10.6 pt up.
                  PositionedDirectional(
                    start: 8.5,
                    end: 8.5,
                    bottom: 8,
                    child: Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(
                        color: white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        shadows: shadows,
                      ),
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

/// A room's picture filling its box: the live cover (CP-015); else the
/// host's photo; else the host's initial on the brand gradient. A picture
/// that fails to load falls back the same way (VG-13).
class KLiveRoomPicture extends StatelessWidget {
  const new({required this.room, super.key});

  final LiveRoomCardData room;

  @override
  Widget build(BuildContext context) {
    final fallback = _Fallback(room: room);
    final cover = room.cover;
    if (cover == null) return fallback;
    return Image(
      image: cover,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
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
