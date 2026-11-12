import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:kabso_live/features/stories/presentation/story_people_carousel.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Input for one account in the stories tray. Production builds it from
/// `GET /feed/stories` (CP-008) with a [username]; tests and the debug
/// previews supply fixtures (no [username]: display only).
@immutable
class FeedStoryData {
  const new({
    required this.authorName,
    this.authorAvatar,
    this.seen = false,
    this.username,
    this.isSelf = false,
    this.hasStory = true,
    this.liveRoomId,
    this.thumbnail,
  });

  final String authorName;
  final ImageProvider? authorAvatar;
  final bool seen;

  /// The account whose stories open on tap.
  final String? username;

  /// The caller's own entry (always first; "Your story").
  final bool isSelf;

  /// `false` for the caller's entry while they have no active story: a
  /// tap adds one. D218: also `false` for someone who is only live.
  final bool hasStory;

  /// D218: the account is live now in this room: the live ring with its
  /// red «مباشر / LIVE» badge; a tap opens the room, not the story.
  final String? liveRoomId;

  /// D375: the card's picture when known up front (previews, tests).
  /// Otherwise a card with a [username] reads the account's stories
  /// (`GET /users/{username}/stories`, the same request the viewer makes)
  /// and shows the first unseen one's thumbnail.
  final ImageProvider? thumbnail;
}

/// D375 (owner «واجعل الستوري تظهر بالخارج بنفس طريقة هذه ١٠٠٪», measured
/// on the owner's reference at 1.20 px/dp; colours, icons and fonts are
/// Kabso's): the stories tray as portrait cards.
abstract final class KStoriesTray {
  /// A card: 80 × 101 dp, 12 dp corners, 8 dp apart, 18 dp from the
  /// screen's sides.
  static const double cardWidth = 80;
  static const double cardHeight = 101;
  static const double radius = KRadius.md;
  static const double gap = KSpacing.sm;
  static const double sideInset = 18;
  static const double top = KSpacing.sm;
  static const double bottom = KSpacing.md;

  /// The author's small picture over the card's top-start corner: 29 dp
  /// with its 2 dp border, 4 dp from the start and 5 dp from the top.
  static const double badge = 29;
  static const double badgeBorder = 2;
  static const double badgeStart = 4;
  static const double badgeTop = 5;

  /// «قصتك»: the caller's 52 dp picture 15 dp from the top, the 24 dp «+»
  /// on its bottom centre, the 12 dp label centred ≈ 87 dp down.
  static const double ownAvatar = 52;
  static const double ownAvatarTop = 15;
  static const double addBadge = 24;
  static const double labelSize = 12;
  static const double labelBottom = 7;

  /// A seen account's card is dimmed (and its small picture's border is
  /// grey), the card's equivalent of the grey ring.
  static const Color seenDim = Color(0x59000000);

  static const double height = top + cardHeight + bottom;
}

/// The horizontal stories tray at the top of «اللحظات» (D375: moved from
/// «الرسائل»): «قصتك» first, then one card per account in the tray's order
/// (each the thumbnail of its first unseen story, with the author's small
/// picture). With [onOpen], an entry with a story opens it and the caller's
/// entry without one calls [onAdd] (its «+» always adds); fixtures without
/// callbacks are display only (no inert controls). It scrolls with the
/// feed, cut at the screen's edge.
class FeedStoriesTray extends StatelessWidget {
  const new({
    required this.stories,
    super.key,
    this.onOpen,
    this.onAdd,
    this.onOpenLive,
    this.ringStyleOf,
  });

  final List<FeedStoryData> stories;
  final ValueChanged<FeedStoryData>? onOpen;
  final VoidCallback? onAdd;

  /// D218: a live entry's tap: opens the room.
  final ValueChanged<String>? onOpenLive;

  /// D374 hook (VIP «STORY_RING», not built): the small picture's ring.
  final StoryRingStyle? Function(FeedStoryData story)? ringStyleOf;

  static const trayKey = Key('feed.stories');
  static Key itemKey(String username) => Key('feed.stories.$username');
  static Key cardKey(String username) => Key('feed.stories.$username.card');
  static Key badgeKey(String username) => Key('feed.stories.$username.badge');
  static const addKey = Key('feed.stories.add');
  static const addBadgeKey = Key('feed.stories.add.badge');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: KStoriesTray.height,
      child: ListView.separated(
        key: trayKey,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(
          KStoriesTray.sideInset,
          KStoriesTray.top,
          KStoriesTray.sideInset,
          KStoriesTray.bottom,
        ),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: KStoriesTray.gap),
        itemBuilder: (context, i) {
          final story = stories[i];
          if (story.isSelf) {
            final adding = !story.hasStory;
            return _OwnCard(
              story: story,
              onTap: adding || onOpen == null || story.username == null
                  ? onAdd
                  : () => onOpen!(story),
              onAdd: onAdd,
            );
          }
          return _StoryCard(
            story: story,
            ringStyle: ringStyleOf?.call(story),
            onTap: switch (story) {
              FeedStoryData(liveRoomId: final room?) when onOpenLive != null =>
                () => onOpenLive!(room),
              FeedStoryData(username: _?) when onOpen != null => () => onOpen!(
                story,
              ),
              _ => null,
            },
          );
        },
      ),
    );
  }
}

/// «قصتك»: a light card, the caller's picture centred with the «+» (Kabso
/// red) on its bottom, the label under it.
class _OwnCard extends StatelessWidget {
  const new({required this.story, this.onTap, this.onAdd});

  final FeedStoryData story;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    final light = Theme.of(context).brightness == Brightness.light;
    final fill = light ? p.surface : p.surfaceRaised;
    final adding = !story.hasStory;
    final card = Material(
      color: fill,
      borderRadius: BorderRadius.circular(KStoriesTray.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: onTap == null ? null : FeedStoriesTray.addKey,
        onTap: onTap,
        child: SizedBox(
          width: KStoriesTray.cardWidth,
          height: KStoriesTray.cardHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              const SizedBox.expand(),
              PositionedDirectional(
                top: KStoriesTray.ownAvatarTop,
                start: 0,
                end: 0,
                child: Center(
                  child: KAvatar(
                    name: story.authorName,
                    image: story.authorAvatar,
                    size: KStoriesTray.ownAvatar,
                    semanticLabel: '',
                  ),
                ),
              ),
              if (onAdd != null || onTap == null)
                PositionedDirectional(
                  top:
                      KStoriesTray.ownAvatarTop +
                      KStoriesTray.ownAvatar -
                      KStoriesTray.addBadge / 2,
                  start: 0,
                  end: 0,
                  child: Center(
                    child: GestureDetector(
                      key: onAdd == null ? null : FeedStoriesTray.addBadgeKey,
                      onTap: onAdd,
                      child: Container(
                        width: KStoriesTray.addBadge,
                        height: KStoriesTray.addBadge,
                        decoration: BoxDecoration(
                          color: p.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: fill, width: 2),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: p.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                bottom: KStoriesTray.labelBottom,
                start: KSpacing.xs,
                end: KSpacing.xs,
                child: Text(
                  l10n.storyYourStory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: t.caption.copyWith(
                    fontSize: KStoriesTray.labelSize,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return ExcludeSemantics(child: card);
    return Semantics(
      button: true,
      label: adding ? l10n.storyAdd : l10n.storyOpenOwn,
      excludeSemantics: true,
      onTap: onTap,
      child: card,
    );
  }
}

/// Someone's card: the thumbnail of their first unseen story (or their
/// picture, or Kabso red), their small picture at the top-start corner;
/// dimmed with a grey border once every story is seen. A live account
/// shows the «LIVE» badge and opens the room.
class _StoryCard extends ConsumerWidget {
  const new({required this.story, this.onTap, this.ringStyle});

  final FeedStoryData story;
  final VoidCallback? onTap;
  final StoryRingStyle? ringStyle;

  ImageProvider? _thumbnail(WidgetRef ref) {
    if (story.thumbnail case final t?) return t;
    final username = story.username;
    if (username == null || !story.hasStory) return null;
    final list = switch (ref.watch(userStoriesProvider(username))) {
      AsyncData(:final value) => value,
      _ => const <Story>[],
    };
    if (list.isEmpty) return null;
    final first = list.firstWhere(
      (s) => !s.viewerHasSeen,
      orElse: () => list.first,
    );
    return NetworkImage(first.media.thumbUrl);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final l10n = context.l10n;
    final live = story.liveRoomId != null;
    final picture = _thumbnail(ref) ?? story.authorAvatar;
    const brand = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [KBrandColors.red600, KBrandColors.red700],
        ),
      ),
    );
    final seen = story.seen && !live;
    final ring = ringStyle;
    const inner = KStoriesTray.badge - 2 * KStoriesTray.badgeBorder;
    final small = ring != null
        ? CustomPaint(
            painter: StoryRingPainter(
              style: ring,
              textDirection: Directionality.of(context),
            ),
            child: SizedBox.square(
              dimension: KStoriesTray.badge,
              child: Center(
                child: KAvatar(
                  name: story.authorName,
                  image: story.authorAvatar,
                  size: inner,
                ),
              ),
            ),
          )
        : Container(
            key: FeedStoriesTray.badgeKey(story.username ?? ''),
            width: KStoriesTray.badge,
            height: KStoriesTray.badge,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: live
                  ? KBrandColors.red500
                  : seen
                  ? p.borderStrong
                  : const Color(0xFFFFFFFF),
            ),
            alignment: Alignment.center,
            child: KAvatar(
              name: story.authorName,
              image: story.authorAvatar,
              size: inner,
            ),
          );
    final card = ClipRRect(
      key: FeedStoriesTray.cardKey(story.username ?? ''),
      borderRadius: BorderRadius.circular(KStoriesTray.radius),
      child: SizedBox(
        width: KStoriesTray.cardWidth,
        height: KStoriesTray.cardHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (picture == null)
              brand
            else
              Image(
                image: picture,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => brand,
              ),
            if (seen) const ColoredBox(color: KStoriesTray.seenDim),
            PositionedDirectional(
              start: KStoriesTray.badgeStart,
              top: KStoriesTray.badgeTop,
              child: small,
            ),
            if (live)
              const PositionedDirectional(
                bottom: KSpacing.sm,
                start: 0,
                end: 0,
                child: Center(child: KBadge.live()),
              ),
            if (onTap != null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: FeedStoriesTray.itemKey(story.username ?? ''),
                  onTap: onTap,
                ),
              ),
          ],
        ),
      ),
    );
    final tap = onTap;
    final label = live
        ? l10n.storyWatchLive(story.authorName)
        : l10n.storyOpen(story.authorName);
    return Semantics(
      button: tap != null,
      label: label,
      value: seen ? l10n.avatarStorySeen : l10n.avatarStoryUnseen,
      onTap: tap,
      excludeSemantics: true,
      child: card,
    );
  }
}
