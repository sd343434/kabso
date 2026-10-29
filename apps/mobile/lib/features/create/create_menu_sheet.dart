import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What the ➕ tab makes (owner, D162).
enum CreateChoice { post, reel, story, live }

/// The ➕ tab's menu (owner, D162): 📝 Post (Create: photos, a video or
/// text), 🎬 Reel (a vertical short video for Moments), ⭕ Story (CP-008)
/// and 🔴 Go live (CP-010). Returns the choice, or `null` when dismissed.
Future<CreateChoice?> showCreateMenu(BuildContext context) =>
    showModalBottomSheet<CreateChoice>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const CreateMenuSheet(),
    );

class CreateMenuSheet extends StatelessWidget {
  const new({super.key});

  static Key choiceKey(CreateChoice choice) =>
      Key('create.menu.${choice.name}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    Widget item(
      CreateChoice choice,
      IconData icon,
      Color color,
      String title,
      String hint,
    ) => ListTile(
      key: choiceKey(choice),
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: t.bodyStrong.copyWith(color: p.textPrimary)),
      subtitle: Text(hint, style: t.caption.copyWith(color: p.textSecondary)),
      onTap: () => Navigator.of(context).pop(choice),
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                0,
                KSpacing.lg,
                KSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(l10n.createMenuTitle, style: t.title),
              ),
            ),
            item(
              CreateChoice.post,
              Icons.edit_note_rounded,
              p.primary,
              l10n.createMenuPost,
              l10n.createMenuPostHint,
            ),
            item(
              CreateChoice.reel,
              Icons.movie_creation_rounded,
              p.primary,
              l10n.createMenuReel,
              l10n.createMenuReelHint,
            ),
            item(
              CreateChoice.story,
              Icons.donut_large_rounded,
              p.primary,
              l10n.createMenuStory,
              l10n.createMenuStoryHint,
            ),
            item(
              CreateChoice.live,
              Icons.sensors_rounded,
              p.error,
              l10n.createMenuLive,
              l10n.createMenuLiveHint,
            ),
            const SizedBox(height: KSpacing.sm),
          ],
        ),
      ),
    );
  }
}
