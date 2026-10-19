import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Presentation-only input for one story in the tray. There is no stories
/// API yet, so nothing in production builds these; tests and the debug
/// previews supply fixtures.
@immutable
class FeedStoryData {
  const new({required this.authorName, this.authorAvatar, this.seen = false});

  final String authorName;
  final ImageProvider? authorAvatar;
  final bool seen;
}

/// Geometry of the stories tray (D52, layout from the owner's reference;
/// sizes on the Kabso scale).
abstract final class KStoriesTray {
  /// One item: the 68 dp ring plus room for a short name.
  static const double itemWidth = KSizes.storyRing + KSpacing.xs;
  static const double gap = KSpacing.md;
}

/// The horizontal stories tray above the posts: story rings with the
/// author's name under each. Opening a story arrives with the stories
/// viewer, so the items are not buttons yet (no inert controls).
class FeedStoriesTray extends StatelessWidget {
  const new({required this.stories, super.key});

  final List<FeedStoryData> stories;

  static const trayKey = Key('feed.stories');

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
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
            SizedBox(
              width: KStoriesTray.itemWidth,
              child: Column(
                children: [
                  KAvatar.story(
                    name: story.authorName,
                    image: story.authorAvatar,
                    ring: story.seen
                        ? KAvatarRing.storySeen
                        : KAvatarRing.storyUnseen,
                  ),
                  const SizedBox(height: KSpacing.xs),
                  ExcludeSemantics(
                    child: Text(
                      story.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: t.caption.copyWith(
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
