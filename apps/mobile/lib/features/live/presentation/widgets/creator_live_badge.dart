import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.82-live (D295, CONVENTIONS §10.108): the purple «صانع محتوى» /
/// "Creator" badge of a content creator's live — on the live card and next to
/// the host's name in the room. The purple is D293's creator seal
/// (`VerificationBadgeColors.creator`, #7B3FC4), drawn in code (no copied art).
class CreatorLiveBadge extends StatelessWidget {
  const new({super.key, this.compact = false});

  /// D293's creator colour.
  static const purple = Color(0xFF7B3FC4);

  static const badgeKey = Key('creatorLiveBadge');

  /// The room's host pill: a smaller pill (no icon).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const white = Color(0xFFFFFFFF);
    return Semantics(
      label: l10n.liveCreatorBadge,
      child: ExcludeSemantics(
        child: Container(
          key: badgeKey,
          padding: EdgeInsetsDirectional.fromSTEB(
            compact ? 5 : 6,
            1,
            compact ? 5 : 7,
            1,
          ),
          decoration: BoxDecoration(
            color: purple,
            borderRadius: BorderRadius.circular(KRadius.pill),
            border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                const Icon(Icons.auto_awesome_rounded, size: 10, color: white),
                const SizedBox(width: 3),
              ],
              Text(
                l10n.liveCreatorBadge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(
                  color: white,
                  fontSize: compact ? 9 : 10,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
