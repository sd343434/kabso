import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Feeds and grids reload after a block or mute changes what they hold.
void _refreshContent(WidgetRef ref) => ref
  ..invalidate(postsFeedProvider)
  ..invalidate(profileGridPagesProvider);

/// Asks, then blocks [username] (CONVENTIONS §11.7: neither side sees the
/// other; follows both ways are removed and not restored by unblocking).
/// `true` when blocked.
Future<bool> confirmBlock(
  BuildContext context,
  WidgetRef ref, {
  required String username,
  required String name,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.safetyBlockTitle(name)),
      content: Text(l10n.safetyBlockBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          key: const Key('safety.block.confirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(
            l10n.safetyBlock,
            style: TextStyle(color: dialog.palette.error),
          ),
        ),
      ],
    ),
  );
  if (!(ok ?? false) || !context.mounted) return false;
  try {
    await ref
        .read(safetyRepositoryProvider)
        .setBlocked(username, blocked: true);
    _refreshContent(ref);
    if (context.mounted) KSnack.success(context, l10n.safetyBlocked(name));
    return true;
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
    return false;
  }
}

/// Mutes [username] (their posts and reposts leave the caller's feeds;
/// they are not told), with Undo on the message.
Future<void> muteUser(
  BuildContext context,
  WidgetRef ref, {
  required String username,
  required String name,
}) async {
  final l10n = context.l10n;
  final repo = ref.read(safetyRepositoryProvider);
  try {
    await repo.setMuted(username, muted: true);
    _refreshContent(ref);
    if (!context.mounted) return;
    KSnack.success(
      context,
      l10n.safetyMuted(name),
      actionLabel: l10n.safetyUndo,
      onAction: () async {
        try {
          await repo.setMuted(username, muted: false);
          _refreshContent(ref);
        } on Object catch (e) {
          if (context.mounted) {
            KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
          }
        }
      },
    );
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}

/// Asks why, then reports the user [userId].
Future<void> reportUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
}) async {
  final l10n = context.l10n;
  final reason = await pickReportReason(context, l10n.safetyReportTitle);
  if (reason == null || !context.mounted) return;
  try {
    await ref.read(safetyRepositoryProvider).reportUser(userId, reason);
    if (context.mounted) KSnack.success(context, l10n.feedPostReported);
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}
