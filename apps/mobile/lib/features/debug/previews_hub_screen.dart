import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/feed_glyphs.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/debug/previews` — KL-056 list of the design previews, so a test build
/// on a phone can reach them without typing a URL. Debug-only route; every
/// screen behind it shows labelled test data.
class PreviewsHubScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final items = [
      (FeedGlyph.homeFilled, l10n.previewsHubFeed, AppRoutes.debugFeedPreview),
      (FeedGlyph.home, l10n.previewsHubReelsTab, AppRoutes.debugPostsPreview),
      (FeedGlyph.profile, l10n.navProfile, AppRoutes.debugProfilePreview),
      (
        FeedGlyph.profile,
        l10n.previewsHubUserProfile,
        AppRoutes.debugUserPreview,
      ),
      (FeedGlyph.comment, l10n.previewsHubReels, AppRoutes.debugReelsPreview),
      (FeedGlyph.discover, l10n.navDiscover, AppRoutes.debugDiscoverPreview),
      (FeedGlyph.live, l10n.previewsHubLive, AppRoutes.debugLivePreview),
      (
        FeedGlyph.comment,
        l10n.previewsHubConversations,
        AppRoutes.debugConversationsPreview,
      ),
      (
        FeedGlyph.smiley,
        l10n.previewsHubMessages,
        AppRoutes.debugMessagesPreview,
      ),
      (FeedGlyph.more, l10n.previewsHubComponents, AppRoutes.debugComponents),
    ];
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        title: Text(l10n.previewsHubTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.md),
        children: [
          Text(
            l10n.previewsHubNote,
            style: context.textStyles.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.md),
          for (final (glyph, label, route) in items)
            Card(
              color: p.surfaceRaised,
              child: ListTile(
                leading: FeedGlyphIcon(glyph, size: 24, color: p.textPrimary),
                title: Text(label),
                trailing: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: p.textTertiary,
                ),
                onTap: () => context.push(route),
              ),
            ),
        ],
      ),
    );
  }
}
