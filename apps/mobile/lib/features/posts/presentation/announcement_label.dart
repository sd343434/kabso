import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.72-live (D283, §10.96.10): the label of an official announcement post
/// or reel «إعلان رسمي — فريق كابسو» in the feeds — a megaphone and the text
/// on the Kabso Team's green and gold, so it never reads as a user's post.
class AnnouncementLabel extends StatelessWidget {
  const new({super.key, this.onMedia = false});

  static const labelKey = Key('post.announcement');

  /// Over a reel's video: light text on a translucent dark pill.
  final bool onMedia;

  static const green = Color(0xFF0F5132);
  static const gold = Color(0xFFE9C46A);

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Semantics(
      container: true,
      label: context.l10n.postAnnouncementLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: labelKey,
          decoration: BoxDecoration(
            color: onMedia ? const Color(0x99000000) : green,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: gold),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.sm,
              vertical: KSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.campaign_rounded, size: 16, color: gold),
                const SizedBox(width: KSpacing.xxs),
                Flexible(
                  child: Text(
                    context.l10n.postAnnouncementLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(
                      color: const Color(0xFFFFF4CF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// D283: the composer's note for a Kabso Team account — what it publishes
/// is an official announcement (the server refuses anything else).
class AnnouncementComposerNote extends StatelessWidget {
  const new({super.key});

  static const noteKey = Key('create.announcementOnly');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      key: noteKey,
      padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // D299i: large enough for its name to read.
              KabsoTeamBadge(height: KabsoTeamBadge.announcementHeight),
              SizedBox(width: KSpacing.sm),
              Flexible(child: AnnouncementLabel()),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            context.l10n.postComposerAnnouncementOnly,
            textAlign: TextAlign.center,
            style: context.textStyles.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}
