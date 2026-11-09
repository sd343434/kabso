import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/compose_widgets.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D333 (owner: «الرفع في الخلفية مع شريط تقدم صغير»): a post being shared
/// while the app is used — a slim bar above the tab bar with the first
/// photo, what it is doing («رفع الصورة 1 من 3…») and the progress;
/// «نعيد المحاولة…» while a lost connection is retried by itself; on a
/// failure the message and Retry. When it goes through, the posted message
/// with View (the post) as a snack bar.
/// Nothing (no height) when there is nothing to show.
class ComposeUploadBar extends ConsumerWidget {
  const new({super.key});

  static const barKey = Key('upload.bar');
  static const failureKey = Key('upload.failure');
  static const progressKey = Key('upload.progress');
  static const retryKey = Key('upload.retry');

  void _announce(BuildContext context, ComposeOutcome outcome) {
    // A draft is announced by Create itself.
    if (outcome.status == 'DRAFT') return;
    final l10n = context.l10n;
    final post = outcome.post;
    final at = outcome.publishAt;
    if (at != null) {
      KSnack.success(context, l10n.createScheduled(scheduleLabel(context, at)));
      return;
    }
    if (post.pendingModeration) {
      KSnack.success(
        context,
        post.video != null
            ? l10n.createPostedVideoInReview
            : l10n.createPostedInReview,
      );
      return;
    }
    KSnack.success(
      context,
      l10n.createPosted,
      actionLabel: l10n.uploadView,
      onAction: () => context.push(AppRoutes.post(post.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The share may finish before this bar is built (Create is left at
    // once): a pending outcome is shown after this frame.
    if (ref.watch(composeOutcomeProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final outcome = ref.read(composeOutcomeProvider);
        if (outcome == null) return;
        ref.read(composeOutcomeProvider.notifier).clear();
        _announce(context, outcome);
      });
    }
    final state = ref.watch(composeControllerProvider);
    final controller = ref.read(composeControllerProvider.notifier);
    final failed = state.failure != null && controller.canRetry;
    if (!state.busy && !failed) return const SizedBox.shrink();
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final total = state.photos.length + (state.video == null ? 0 : 1);
    final progress = switch (state.phase) {
      ComposePhase.publishing => null as double?,
      _ when state.video != null => state.progress,
      _ when total > 0 => state.uploaded / total,
      _ => null,
    };
    final thumb = state.photos.firstOrNull?.bytes;
    return Material(
      key: barKey,
      color: p.surfaceRaised,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md,
                vertical: KSpacing.xs,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KRadius.sm),
                    child: SizedBox.square(
                      dimension: 36,
                      child: thumb != null
                          ? Image.memory(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  ColoredBox(color: p.surfaceOverlay),
                            )
                          : ColoredBox(
                              color: p.surfaceOverlay,
                              child: Icon(
                                state.video != null
                                    ? Icons.play_arrow_rounded
                                    : Icons.notes_rounded,
                                size: 20,
                                color: p.textSecondary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Semantics(
                      key: failed ? failureKey : null,
                      liveRegion: true,
                      child: Text(
                        failed
                            ? composeFailureMessage(
                                l10n,
                                state.failure!,
                                video: state.video != null,
                              )
                            : state.retrying
                            ? l10n.uploadRetrying
                            : composeProgressLabel(l10n, state),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(
                          color: failed ? p.error : p.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (failed) ...[
                    TextButton(
                      key: retryKey,
                      onPressed: controller.retry,
                      child: Text(l10n.actionRetry),
                    ),
                  ],
                ],
              ),
            ),
            if (!failed)
              LinearProgressIndicator(
                key: progressKey,
                value: progress,
                minHeight: 3,
                color: p.primary,
                backgroundColor: p.border,
              ),
          ],
        ),
      ),
    );
  }
}

/// What a share is doing: «Uploading photo 1 of 3», «Uploading the video…
/// 40%» or «Publishing…» (Create's progress and the upload bar).
String composeProgressLabel(AppLocalizations l10n, ComposeState draft) {
  final video = draft.video != null;
  final total = draft.photos.length;
  final uploading =
      draft.phase == ComposePhase.uploading && (total > 0 || video);
  final current = draft.uploaded + 1 > total ? total : draft.uploaded + 1;
  return uploading && video
      ? l10n.createUploadingVideo((draft.progress * 100).floor())
      : uploading
      ? l10n.createUploading(current, total)
      : l10n.createPublishing;
}

/// Why a share failed (Create's banner and the upload bar).
String composeFailureMessage(
  AppLocalizations l10n,
  AppFailure failure, {
  bool video = false,
}) => switch (failure) {
  ServerFailure(code: ErrorCode.mediaUploadsUnavailable) =>
    video ? l10n.createVideoUploadsUnavailable : l10n.createUploadsUnavailable,
  ServerFailure(code: ErrorCode.mediaInvalid) =>
    video ? l10n.createVideoInvalid : l10n.createPhotoInvalid,
  _ => failureMessage(l10n, failure),
};
