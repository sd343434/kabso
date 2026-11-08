import 'dart:async';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_feedback_sheet.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.95-social (D301, §10.112.1): the cover video layer of [profile] when it
/// is the app owner's and a video exists for the app's language (or the
/// only one); null otherwise (the cover picture shows).
Widget? ownerCoverVideoFor(BuildContext context, PublicProfile profile) {
  if (!profile.kabsoOwner) return null;
  final video = profile.coverVideo?.pick(
    Localizations.localeOf(context).languageCode,
  );
  if (video == null) return null;
  return OwnerCoverVideoLayer(video: video);
}

/// v1.95-social (D301, §10.112.6): the visitor's row on the app owner's page
/// — «متابعة المؤسس» (Kabso red, no shadow since D307; «تتابع المؤسس» / «تم الطلب» once done, a
/// tap asks before undoing), «اقترح ميزة / أبلغ عن موظف» (gold; D307, owner:
/// «اجعله فقط بإطار مفرغ» — an outline only, no fill) and the more button.
class OwnerVisitorActions extends StatelessWidget {
  const new({
    required this.following,
    required this.requested,
    required this.onFollow,
    required this.more,
    super.key,
  });

  final bool following;
  final bool requested;
  final VoidCallback onFollow;
  final Widget more;

  static const followKey = Key('owner.follow');
  static const feedbackKey = Key('owner.feedbackButton');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KRadius.sm + 2),
    );
    final done = following || requested;
    final follow = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.sm + 2),
        gradient: done
            ? null
            : const LinearGradient(
                colors: [KBrandColors.red400, KBrandColors.red600],
              ),
        // D307 (owner: «ازل الظلال الذي اسفل زر متابعة المؤسس»): no shadow
        // or glow under it, in either state.
      ),
      child: done
          ? OutlinedButton.icon(
              key: followKey,
              style: ProfileCoverButtons.quiet(context)
                  .copyWith(shape: WidgetStatePropertyAll(shape)),
              onPressed: onFollow,
              icon: Icon(
                requested ? Icons.schedule_rounded : Icons.check_rounded,
                size: 18,
              ),
              label: ProfileCoverButtons.label(
                requested ? l10n.followRequested : l10n.ownerFollowing,
              ),
            )
          : FilledButton.icon(
              key: followKey,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0x00000000),
                shadowColor: const Color(0x00000000),
                foregroundColor: const Color(0xFFFFFFFF),
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
                textStyle: context.textStyles.bodyStrong,
              ),
              onPressed: onFollow,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: ProfileCoverButtons.label(l10n.ownerFollow),
            ),
    );
    final feedback = OutlinedButton.icon(
      key: feedbackKey,
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? KBrandColors.gold
            : const Color(0xFF9A6B00),
        // D307: outline only (the page shows through), in both themes.
        backgroundColor: const Color(0x00000000),
        side: BorderSide(color: KBrandColors.gold.withValues(alpha: 0.85)),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
        textStyle: context.textStyles.bodyStrong,
      ),
      onPressed: () => unawaited(showOwnerFeedbackSheet(context)),
      icon: const Icon(Icons.forum_rounded, size: 18),
      label: ProfileCoverButtons.label(l10n.ownerFeedbackButton),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: follow),
        const SizedBox(width: KSpacing.sm),
        Expanded(child: feedback),
        const SizedBox(width: KSpacing.sm),
        more,
      ],
    );
  }
}
