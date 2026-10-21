import 'package:kabso_live/design_system/design_system.dart';
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
  });

  final String authorName;
  final ImageProvider? authorAvatar;
  final bool seen;

  /// The account whose stories open on tap.
  final String? username;

  /// The caller's own entry (always first; "Your story").
  final bool isSelf;

  /// `false` for the caller's entry while they have no active story: a
  /// tap adds one.
  final bool hasStory;
}

/// Geometry of the stories tray (D52, layout from the owner's reference;
/// sizes on the Kabso scale).
abstract final class KStoriesTray {
  /// One item: the 68 dp ring plus room for a short name.
  static const double itemWidth = KSizes.storyRing + KSpacing.xs;
  static const double gap = KSpacing.md;
}

/// The horizontal stories tray above the posts: story rings with the
/// author's name under each. With [onOpen], an entry with a story opens it
/// and the caller's entry without one calls [onAdd] ("Your story" with a
/// "+"); fixtures without callbacks are display only (no inert controls).
class FeedStoriesTray extends StatelessWidget {
  const new({required this.stories, super.key, this.onOpen, this.onAdd});

  final List<FeedStoryData> stories;
  final ValueChanged<FeedStoryData>? onOpen;
  final VoidCallback? onAdd;

  static const trayKey = Key('feed.stories');
  static Key itemKey(String username) => Key('feed.stories.$username');
  static const addKey = Key('feed.stories.add');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: trayKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, story) in stories.indexed) ...[
            if (i > 0) const SizedBox(width: KStoriesTray.gap),
            _TrayItem(
              story: story,
              onTap: switch (story) {
                FeedStoryData(isSelf: true, hasStory: false) => onAdd,
                FeedStoryData(username: _?) when onOpen != null =>
                  () => onOpen!(story),
                _ => null,
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TrayItem extends StatelessWidget {
  const new({required this.story, this.onTap});

  final FeedStoryData story;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    final l10n = context.l10n;
    final adding = story.isSelf && !story.hasStory;
    final label = story.isSelf ? l10n.storyYourStory : story.authorName;
    final item = SizedBox(
      width: KStoriesTray.itemWidth,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              KAvatar.story(
                name: story.authorName,
                image: story.authorAvatar,
                ring: adding
                    ? KAvatarRing.none
                    : story.seen
                    ? KAvatarRing.storySeen
                    : KAvatarRing.storyUnseen,
              ),
              if (story.isSelf && onTap != null)
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: p.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.background, width: 2),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: p.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          ExcludeSemantics(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return item;
    return Semantics(
      button: true,
      label: adding ? l10n.storyAdd : l10n.storyOpen(label),
      excludeSemantics: true,
      onTap: tap,
      child: InkWell(
        key: adding
            ? FeedStoriesTray.addKey
            : FeedStoriesTray.itemKey(story.username ?? ''),
        borderRadius: BorderRadius.circular(KRadius.md),
        onTap: tap,
        child: item,
      ),
    );
  }
}
