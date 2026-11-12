import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D375 (owner 2026-11-11, «طبق التصميم ١٠٠٪» 2026-11-12): geometry and
/// timing of the story viewer's people carousel, measured on the owner's
/// reference (its phone ≈ 216 px for 393 dp: 0.552 px/dp). The layout is
/// the reference's; colours, fonts and icons are Kabso's.
abstract final class KStoryCarousel {
  /// The centred person's ring, outside diameter (reference ≈ 113 dp).
  static const double centre = 112;

  /// A neighbour's photo, outside diameter (reference ≈ 68 dp), at full
  /// opacity.
  static const double side = 68;

  /// The space between two circles' edges (reference 17–18 dp): centre to
  /// neighbour ≈ 108 dp, neighbour to neighbour 86 dp, so at 393 dp the
  /// second neighbour on each side is cut in half by the screen's edge.
  static const double gap = 18;

  /// A thin ring (reference ≈ 2.5 dp) with a ≈ 3 dp gap before the photo;
  /// a neighbour's ring scales down with it.
  static const double ringStroke = 2.5;
  static const double seenStroke = 1.5;
  static const double ringGap = 3;

  /// Names: the centred one 14 dp white, ≈ 12 dp under its ring; the
  /// neighbours' 11 dp, faded, ≈ 13 dp under theirs.
  static const double centreName = 14;
  static const double sideName = 11;
  static const double nameGap = 12;
  static const Color sideNameColor = Color(0x99FFFFFF);

  /// A swipe of this many dp moves one person.
  static const double dragPerPerson = 97;

  /// The recommended behaviour: the carousel shows when the viewer opens
  /// and on every change of person, then fades out after this long so the
  /// story is unobstructed. Touching the lower area, a long press (pause)
  /// or typing a reply brings it back and keeps it up.
  static const Duration autoHide = Duration(seconds: 2);

  /// The frosted fade behind the carousel and the caption: from this far
  /// above the screen's bottom (reference: it starts ≈ 480 dp down a
  /// 852 dp screen), the photo blurs more and more under a light tint.
  static const double frostHeight = 372;
  static const List<double> frostBands = [
    0,
    0.08,
    0.16,
    0.24,
    0.32,
    0.4,
    0.48,
    0.56,
  ];
  static const List<double> frostSigmas = [0.5, 1, 1.5, 2, 3, 4, 5, 6];
  static const Color frostClear = Color(0x00FFFFFF);
  static const Color frostMid = Color(0x24FFFFFF);
  static const Color frostBottom = Color(0x4DFFFFFF);

  /// The seen ring (`color.dark.textTertiary`: the viewer is always dark).
  static const Color seenRing = Color(0xFF92929E);

  /// Horizontal centre offset of a person [d] places from the centre.
  static double offsetOf(double d) {
    final a = d.abs();
    const first = centre / 2 + gap + side / 2;
    final x = a <= 1 ? a * first : first + (a - 1) * (side + gap);
    return d.isNegative ? -x : x;
  }
}

/// How a story ring is drawn: a gradient along the ring (one colour is a
/// plain ring) and its stroke.
///
/// D374 hook: the VIP «STORY_RING» perk (not built yet) will pass its own
/// style through [StoryPeopleCarousel.ringStyleOf] (and the tray's
/// `FeedStoriesTray.ringStyleOf`); nothing here grants it.
@immutable
class StoryRingStyle {
  const new({required this.colors, this.stroke = KStoryCarousel.ringStroke});

  /// Unseen stories: brand red to gold (`color.brand.red500`, `red400`,
  /// `gold`).
  static const unseen = StoryRingStyle(
    colors: [KBrandColors.red500, KBrandColors.red400, KBrandColors.gold],
  );

  /// Every story of this person seen: a thin grey ring.
  static const seen = StoryRingStyle(
    colors: [KStoryCarousel.seenRing],
    stroke: KStoryCarousel.seenStroke,
  );

  final List<Color> colors;
  final double stroke;
}

/// Paints [style] as a ring inside the box (the stroke scaled by [scale]).
class StoryRingPainter extends CustomPainter {
  new({required this.style, required this.textDirection, this.scale = 1});

  final StoryRingStyle style;
  final TextDirection textDirection;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(1, style.stroke * scale).toDouble();
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;
    if (style.colors.length == 1) {
      paint.color = style.colors.single;
    } else {
      // Red at the top on the reading-end side, gold at the bottom on the
      // start side.
      paint.shader = LinearGradient(
        begin: AlignmentDirectional.topEnd,
        end: AlignmentDirectional.bottomStart,
        colors: style.colors,
      ).createShader(rect, textDirection: textDirection);
    }
    canvas.drawCircle(
      rect.center,
      (math.min(size.width, size.height) - stroke) / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(StoryRingPainter old) =>
      old.style != style ||
      old.scale != scale ||
      old.textDirection != textDirection;
}

/// D375: the people who have stories, in tray order (reading order: the
/// first on the right in Arabic, as in the tray), with [current] centred
/// and larger. Swiping and letting go on someone, or tapping them, calls
/// [onSelect] with their index; a change of [current] glides them to the
/// centre (instantly when the platform asks to reduce motion).
class StoryPeopleCarousel extends StatefulWidget {
  const new({
    required this.people,
    required this.current,
    required this.onSelect,
    super.key,
    this.seen = _noneSeen,
    this.ringStyleOf,
  });

  final List<FeedStoryData> people;
  final int current;
  final ValueChanged<int> onSelect;

  /// Whether every story of a person has been seen (grey ring).
  final bool Function(FeedStoryData person) seen;

  /// D374 hook (VIP «STORY_RING», not built): a person's own ring style;
  /// `null` keeps the default.
  final StoryRingStyle? Function(FeedStoryData person)? ringStyleOf;

  static const carouselKey = Key('story.carousel');
  static Key personKey(String username) => Key('story.carousel.$username');

  static bool _noneSeen(FeedStoryData _) => false;

  /// The carousel's height at [textScaler].
  static double heightFor(TextScaler textScaler) =>
      KStoryCarousel.centre +
      KStoryCarousel.nameGap +
      textScaler.scale(KStoryCarousel.centreName) * 1.3;

  @override
  State<StoryPeopleCarousel> createState() => _StoryPeopleCarouselState();
}

class _StoryPeopleCarouselState extends State<StoryPeopleCarousel>
    with SingleTickerProviderStateMixin {
  /// The person at the centre, fractional while moving.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.current.toDouble(),
  );

  @override
  void didUpdateWidget(StoryPeopleCarousel old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) unawaited(_glide(widget.current));
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  Future<void> _glide(int index) async {
    final duration = KMotion.of(context, KMotion.slow);
    if (duration == Duration.zero) {
      _position.value = index.toDouble();
      return;
    }
    await _position.animateTo(
      index.toDouble(),
      duration: duration,
      curve: KMotion.standard,
    );
  }

  double get _sign => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _drag(DragUpdateDetails d) {
    _position.stop();
    final max = (widget.people.length - 1).toDouble();
    _position.value =
        (_position.value - _sign * d.delta.dx / KStoryCarousel.dragPerPerson)
            .clamp(-0.4, max + 0.4);
  }

  void _release(DragEndDetails d) {
    final fling = -_sign * (d.primaryVelocity ?? 0) / 1000;
    final target = (_position.value + fling.clamp(-1.0, 1.0)).round().clamp(
      0,
      widget.people.length - 1,
    );
    if (target != widget.current) {
      widget.onSelect(target);
    } else {
      unawaited(_glide(target));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final height = StoryPeopleCarousel.heightFor(scaler);
    return GestureDetector(
      key: StoryPeopleCarousel.carouselKey,
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _drag,
      onHorizontalDragEnd: _release,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, box) => AnimatedBuilder(
            animation: _position,
            builder: (context, _) {
              final mid = box.maxWidth / 2;
              final children = <(double, Widget)>[];
              for (final (i, person) in widget.people.indexed) {
                final d = i - _position.value;
                final x = mid + _sign * KStoryCarousel.offsetOf(d);
                const slot = KStoryCarousel.centre + KStoryCarousel.gap;
                if (x < -slot || x > box.maxWidth + slot) continue;
                final focus = 1 - d.abs().clamp(0.0, 1.0);
                children.add((
                  focus,
                  Positioned(
                    left: x - slot / 2,
                    top: 0,
                    width: slot,
                    height: height,
                    child: _Person(
                      person: person,
                      focus: focus,
                      selected: i == widget.current,
                      seen: widget.seen(person),
                      style: widget.ringStyleOf?.call(person),
                      onTap: () {
                        if (i != widget.current) widget.onSelect(i);
                      },
                    ),
                  ),
                ));
              }
              // The centred person on top.
              children.sort((a, b) => a.$1.compareTo(b.$1));
              return Stack(
                clipBehavior: Clip.none,
                children: [for (final (_, w) in children) w],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const new({
    required this.person,
    required this.focus,
    required this.selected,
    required this.seen,
    required this.onTap,
    this.style,
  });

  final FeedStoryData person;

  /// 1 when centred, 0 one place or more away.
  final double focus;
  final bool selected;
  final bool seen;
  final StoryRingStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final ring = style ?? (seen ? StoryRingStyle.seen : StoryRingStyle.unseen);
    final outer = lerpDouble(
      KStoryCarousel.side,
      KStoryCarousel.centre,
      focus,
    )!;
    final scale = outer / KStoryCarousel.centre;
    final image =
        outer -
        2 * (KStoryCarousel.ringStroke + KStoryCarousel.ringGap) * scale;
    final name = person.isSelf ? l10n.storyYourStory : person.authorName;
    final label = person.isSelf
        ? l10n.storyOpenOwn
        : l10n.storyPeopleOf(person.authorName);
    final nameSize = lerpDouble(
      KStoryCarousel.sideName,
      KStoryCarousel.centreName,
      focus,
    )!;
    final nameColor = Color.lerp(
      KStoryCarousel.sideNameColor,
      const Color(0xFFFFFFFF),
      focus,
    )!;
    // Circle centres line up; each name sits under its own circle.
    const top = 0.0;
    final circleTop = top + (KStoryCarousel.centre - outer) / 2;
    final nameTop =
        circleTop +
        outer +
        lerpDouble(KStoryCarousel.nameGap + 1, KStoryCarousel.nameGap, focus)!;
    // A neighbour's name keeps to its own place.
    final inset =
        (KStoryCarousel.centre - KStoryCarousel.side) / 2 * (1 - focus);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            top: circleTop,
            start: 0,
            end: 0,
            height: outer,
            child: Center(
              child: GestureDetector(
                key: StoryPeopleCarousel.personKey(person.username ?? ''),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: CustomPaint(
                  painter: StoryRingPainter(
                    style: ring,
                    scale: scale,
                    textDirection: Directionality.of(context),
                  ),
                  child: SizedBox.square(
                    dimension: outer,
                    child: Center(
                      child: KAvatar(
                        name: person.authorName,
                        image: person.authorAvatar,
                        size: image,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: nameTop,
            start: inset,
            end: inset,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.label.copyWith(
                fontSize: nameSize,
                fontWeight: FontWeight.lerp(
                  FontWeight.w400,
                  FontWeight.w500,
                  focus,
                ),
                height: 1.3,
                color: nameColor,
                shadows: KLiveColors.glassShadow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
