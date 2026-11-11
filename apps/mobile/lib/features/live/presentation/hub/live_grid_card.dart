import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/creator_live_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_rocket_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_type_tag.dart';
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

  /// D248 (ref 375): the carousel's gap below the first row (12 px ≈ 6.4
  /// pt) and above the next one (21 px ≈ 11.2 pt). D303: the carousel is the
  /// first block; [bannerBottom] is its gap above the first row.
  static const double bannerTop = 6.4;
  static const double bannerBottom = 11.2;

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
/// - Top start: the animated live mark ([KLiveEqualizer], teal) and the
///   room type right beside it — D362 (owner: «ايقونة تكون ببطاقة البث من
///   الخارج حسب نوع البث بخط صغير جداً», then 2026-11-10: «لا ازل الايقونات
///   فقط جنبي موجة الكلمة بتصنيف لايف»): the tiny English tag only, no glyph
///   ([LiveTypeTag], [LiveCardKind.of]: PK, streamer, podcast, audio, multi
///   or a camera live), the same for every kind (it replaced the type text
///   and D342b's party chip). Top end: the viewer count with
///   a person icon (owner 2026-11-08: «المعلومات على بطاقة البث كثيرة» —
///   one type and the viewers; the «جديد» chip is gone, 0 is shown as 0:
///   the real count, never invented).
/// - A content creator's live: the small creator mark ([CreatorLiveBadge]
///   `iconOnly`) under the type.
/// - Bottom, over a scrim: only the title the host set (the host's name when
///   it is empty), up to 2 lines with an ellipsis; «مميز» above it. The
///   host's name and the category are announced, not drawn (ref 165).
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

  /// The card's only text at the bottom: the live's title (2 lines).
  static const titleKey = Key('liveGrid.title');

  /// D337: no cover and no host photo — the owner's default picture.
  static const defaultAvatarKey = Key('liveGrid.defaultAvatar');

  /// D154b: the «مميز» label of a live with a running traffic card.
  static const featuredKey = Key('liveGrid.featured');

  /// D233: the animated «مميز» frame of a live with a rocket stage running
  /// (the stage's rocket is inside the «مميز» pill, [featuredKey]).
  static const frameKey = Key('liveGrid.frame');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    const shadows = [
      Shadow(color: Color(0x80000000), blurRadius: 4, offset: Offset(0, 1)),
    ];
    // D237 (owner): every card names its live's category, from the room's
    // own mode (the hub has no category row any more): «بث مباشر»,
    // «بث صوتي», «بث بودكاست», «بث متعدد»; a PK keeps «PK». D213: a
    // streamer's card «ستريمر».
    final type = room.inPk
        ? l10n.pkBadge
        : room.isStreamer
        ? l10n.liveCardTagStreamer
        : room.isPodcast
        ? l10n.liveCategoryPodcast
        : room.isAudio
        ? l10n.liveCategoryAudio
        : room.isMulti
        ? l10n.liveCategoryMulti
        : l10n.liveCategoryLive;
    // D362: the same kind as a tiny tag beside the live wave.
    final kind = LiveCardKind.of(room);
    final title = room.title.trim().isEmpty ? room.hostName : room.title;
    final base = l10n.liveCardSemantics(
      room.hostName,
      l10n.liveViewers(room.viewerCount, KFormat.grouped(room.viewerCount)),
      title,
    );
    final withType = l10n.liveCardSemanticsMode(
      room.hostIsCreator ? '$base, ${l10n.liveCreatorBadge}' : base,
      type,
    );
    final category = room.categoryName;
    final hasCategory = category != null && category.isNotEmpty;
    final described = hasCategory
        ? l10n.liveCardSemanticsCategory(withType, category)
        : withType;
    final stage = room.boostStage;
    final semantics = room.featured
        ? stage > 0
              ? '${l10n.liveBoostFeatured}, ${l10n.liveRocketStage(stage)}, '
                    '$described'
              : '${l10n.liveBoostFeatured}, $described'
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
                          const SizedBox(width: KSpacing.xs),
                          // D362: the type's tiny tag, right beside the
                          // wave, takes the room the count leaves (a
                          // narrow card shrinks it, never the count).
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: LiveTypeTag(
                                key: typeKey,
                                kind: kind,
                                // D363: a video podcast's camera.
                                video: room.podcast?.video ?? false,
                              ),
                            ),
                          ),
                          const SizedBox(width: KSpacing.xs),
                          Row(
                            key: viewersKey,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 13,
                                color: white,
                                shadows: shadows,
                              ),
                              const SizedBox(width: KSpacing.xxs),
                              Text(
                                KFormat.compact(room.viewerCount, l10n),
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
                  // v1.82-live (D295): a content creator's live — the small
                  // purple creator mark under the live mark (owner
                  // 2026-11-08: an icon, not the worded pill).
                  if (room.hostIsCreator)
                    const PositionedDirectional(
                      top: 27,
                      start: 8.5,
                      child: CreatorLiveBadge(iconOnly: true),
                    ),
                  // Ref 165: the title 8.5 pt in, its baseline 10.6 pt up —
                  // up to 2 lines (owner 2026-11-08). D154b: «مميز» over it
                  // (a running traffic card); D233 follow-up: with a rocket
                  // stage, its rocket inside the pill and the stage's colours.
                  PositionedDirectional(
                    start: 8.5,
                    end: 8.5,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (room.featured) ...[
                          DefaultTextStyle.merge(
                            style: t.caption,
                            child: KFeaturedPill(
                              key: featuredKey,
                              label: l10n.liveBoostFeatured,
                              stage: stage,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          title,
                          key: titleKey,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            color: white,
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            shadows: shadows,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // D233: the animated «مميز» frame, its intensity by stage.
            if (stage > 0) KBoostFrame(key: frameKey, stage: stage),
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
/// host's photo; else (D337) the owner's default picture. A picture
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

/// No (working) cover: the host's photo filling the card, else (D337) the
/// owner's default picture (it replaced the initial on the brand gradient).
class _Fallback extends StatelessWidget {
  const new({required this.room});

  final LiveRoomCardData room;

  @override
  Widget build(BuildContext context) {
    const none = KDefaultAvatarImage(key: KLiveGridCard.defaultAvatarKey);
    final avatar = room.hostAvatar;
    if (avatar == null) return none;
    return Image(
      image: avatar,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => none,
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
