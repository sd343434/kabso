import 'package:clock/clock.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Presentation-only input for one Home feed item. There is no feed API
/// yet (posts Phase 3, short video Phase 5), so nothing in production
/// builds these; tests use `test/fixtures/` and debug builds the gallery.
@immutable
class FeedPostData {
  const new({
    required this.authorName,
    required this.postedAt,
    this.authorAvatar,
    this.text,
    this.media,
    this.mediaAspect,
  });

  final String authorName;
  final ImageProvider? authorAvatar;
  final DateTime postedAt;
  final String? text;

  /// Photo or video cover; `null` for a text-only post.
  final ImageProvider? media;

  /// Width / height of [media]; `KMetrics.feedMediaAspect` when unknown.
  final double? mediaAspect;
}

/// A full-width, flat feed item (no card container, VG-25): author row
/// (avatar, name, relative time), up to 4 lines of text, then the media at
/// its own aspect ratio with radius `sm`. No action buttons until the
/// like/comment APIs exist.
class FeedPostTile extends StatelessWidget {
  const new({required this.post, super.key});

  final FeedPostData post;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final when =
        KFormat.relative(
          post.postedAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    final text = post.text;
    final media = post.media;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: KAvatar(
                    name: post.authorName,
                    image: post.authorAvatar,
                    size: KSizes.avatarSm,
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Text(
                    post.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong,
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Text(when, style: t.caption),
              ],
            ),
            if (text != null && text.isNotEmpty) ...[
              const SizedBox(height: KSpacing.sm),
              Text(
                text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: t.body,
              ),
            ],
            if (media != null) ...[
              const SizedBox(height: KSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(KRadius.sm),
                child: AspectRatio(
                  aspectRatio: post.mediaAspect ?? KMetrics.feedMediaAspect,
                  child: ColoredBox(
                    color: context.palette.surfaceRaised,
                    child: Image(
                      image: media,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder with the tile's anatomy.
class FeedPostSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.symmetric(
      horizontal: KSpacing.lg,
      vertical: KSpacing.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            KSkeleton(height: KSizes.avatarSm, circle: true),
            SizedBox(width: KSpacing.sm),
            KSkeleton(width: KSizes.avatarLg, height: KSpacing.md),
          ],
        ),
        SizedBox(height: KSpacing.sm),
        KSkeleton(width: double.infinity, height: KSpacing.md),
        SizedBox(height: KSpacing.sm),
        AspectRatio(
          aspectRatio: KMetrics.feedMediaAspect * 4 / 3,
          child: KSkeleton(width: double.infinity, height: double.infinity),
        ),
      ],
    ),
  );
}
