import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D375 (owner 2026-11-11): geometry and timing of the story viewer's
/// people carousel (a layout idea from a reference; Kabso's own tokens).
abstract final class KStoryCarousel {
  /// The centred person's ring, outside diameter.
  static const double centre = 68;

  /// A neighbour's ring, outside diameter.
  static const double side = 44;

  /// A neighbour's opacity (the centred person is opaque).
  static const double sideOpacity = 0.55;

  /// Each person's slot as a share of the carousel's width: at 393 dp the
  /// second neighbour on each side is cut by the screen's edge.
  static const double slotFraction = 0.235;

  /// Ring strokes: the coloured ring and the thinner seen ring, with a
  /// dark gap between the ring and the photo.
  static const double ringStroke = KMetrics.strokeLarge;
  static const double seenStroke = KMetrics.stroke;
  static const double ringGap = KMetrics.ringGap;

  /// The recommended behaviour: the carousel shows when the viewer opens
  /// and on every change of person, then fades out after this long so the
  /// story is unobstructed. Touching the lower area, a long press (pause)
  /// or typing a reply brings it back and keeps it up.
  static const Duration autoHide = Duration(seconds: 2);

  /// A soft dark fade over the bottom of the photo behind the carousel.
  static const double scrimHeight = 300;
  static const Color scrimBottom = Color(0x99000000);
  static const Color scrimClear = Color(0x00000000);

  /// The seen ring (`color.dark.textTertiary`: the viewer is always dark).
  static const Color seenRing = Color(0xFF92929E);
}

/// How a story ring is drawn: a gradient along the ring (one colour is a
/// plain ring) and its stroke.
///
/// D374 hook: the VIP «STORY_RING» perk (not built yet) will pass its own
/// style through [StoryPeopleCarousel.ringStyleOf]; nothing here grants it.
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
    final stroke = style.stroke * scale;
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

  @override
  State<StoryPeopleCarousel> createState() => _StoryPeopleCarouselState();
}

class _StoryPeopleCarouselState extends State<StoryPeopleCarousel> {
  late final PageController _pages = PageController(
    initialPage: widget.current,
    viewportFraction: KStoryCarousel.slotFraction,
  );

  /// Set while a finger drives the scroll; its end selects the person.
  bool _dragging = false;

  @override
  void didUpdateWidget(StoryPeopleCarousel old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) _centre(widget.current);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _centre(int index) {
    if (!_pages.hasClients) return;
    final duration = KMotion.of(context, KMotion.slow);
    if (duration == Duration.zero) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(index, duration: duration, curve: KMotion.standard);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _dragging = true;
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      final page = (_pages.page ?? widget.current.toDouble()).round();
      if (page != widget.current) {
        widget.onSelect(page);
      }
    }
    return false;
  }

  double _name(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(KTypography.label.size) *
      KTypography.label.height;

  @override
  Widget build(BuildContext context) {
    final height = KStoryCarousel.centre + KSpacing.xs + _name(context) + 2;
    return SizedBox(
      key: StoryPeopleCarousel.carouselKey,
      height: height,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _pages,
          itemCount: widget.people.length,
          clipBehavior: Clip.none,
          itemBuilder: (context, i) => AnimatedBuilder(
            animation: _pages,
            builder: (context, _) {
              final page = _pages.hasClients && _pages.position.haveDimensions
                  ? _pages.page ?? widget.current.toDouble()
                  : widget.current.toDouble();
              final focus = 1 - (page - i).abs().clamp(0.0, 1.0);
              return _Person(
                person: widget.people[i],
                focus: focus,
                selected: i == widget.current,
                seen: widget.seen(widget.people[i]),
                style: widget.ringStyleOf?.call(widget.people[i]),
                onTap: () {
                  if (i != widget.current) {
                    widget.onSelect(i);
                  }
                },
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

  /// 1 when centred, 0 one slot or more away.
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: StoryPeopleCarousel.personKey(person.username ?? ''),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: lerpDouble(KStoryCarousel.sideOpacity, 1, focus)!,
          child: Column(
            children: [
              SizedBox(
                height: KStoryCarousel.centre,
                child: Center(
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
              const SizedBox(height: KSpacing.xs),
              if (focus > 0)
                Opacity(
                  opacity: focus,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.xxs,
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: t.label.copyWith(
                        color: const Color(0xFFFFFFFF),
                        shadows: KLiveColors.glassShadow,
                      ),
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
