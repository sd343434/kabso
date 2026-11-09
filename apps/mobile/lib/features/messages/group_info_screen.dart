import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/application/dm_group_providers.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/group_chat_screen.dart';
import 'package:kabso_live/features/messages/widgets/dm_group_row.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/message-groups/:groupId/info` (D339, CONVENTIONS §10.133) «معلومات
/// المجموعة»: the photo, the name and the member count; the members (admins
/// first, the creator marked); for admins: rename, change or remove the
/// photo, «إضافة أعضاء» and, per member, make / remove admin and remove from
/// the group (never the creator, never oneself); for everyone: mute,
/// archive, report and «مغادرة المجموعة».
class GroupInfoScreen extends ConsumerWidget {
  const new({required this.groupId, super.key});

  final String groupId;

  static const renameKey = Key('dm.group.info.rename');
  static const photoKey = Key('dm.group.info.photo');
  static const addKey = Key('dm.group.info.add');
  static const leaveKey = Key('dm.group.info.leave');
  static const muteKey = Key('dm.group.info.mute');
  static const archiveKey = Key('dm.group.info.archive');
  static const reportKey = Key('dm.group.info.report');
  static const renameFieldKey = Key('dm.group.info.rename.field');
  static const renameSaveKey = Key('dm.group.info.rename.save');
  static Key memberKey(String username) => Key('dm.group.member.$username');
  static const makeAdminKey = Key('dm.group.member.admin');
  static const removeAdminKey = Key('dm.group.member.unadmin');
  static const removeKey = Key('dm.group.member.remove');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final detail = ref.watch(dmGroupDetailProvider(groupId));
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        title: Text(l10n.dmGroupInfo),
      ),
      body: switch (detail) {
        AsyncValue(:final value?) => _Info(groupId: groupId, detail: value),
        AsyncValue(:final error?) =>
          toAppFailure(error).code == ErrorCode.notFound
              ? KEmptyState(
                  icon: Icons.group_off_outlined,
                  title: l10n.dmGroupUnavailable,
                  message: l10n.dmRetentionNotice,
                )
              : FailureErrorState(
                  title: l10n.errorTitle,
                  failure: toAppFailure(error),
                  onRetry: () => ref.invalidate(dmGroupDetailProvider(groupId)),
                ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Info extends ConsumerStatefulWidget {
  const new({required this.groupId, required this.detail});

  final String groupId;
  final DmGroupDetail detail;

  @override
  ConsumerState<_Info> createState() => _InfoState();
}

class _InfoState extends ConsumerState<_Info> {
  bool _busy = false;

  DmGroupsRepository get _repo => ref.read(dmGroupsRepositoryProvider);

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(dmGroupDetailProvider(widget.groupId))
        ..invalidate(dmGroupChatProvider(widget.groupId));
      if (done != null && mounted) KSnack.success(context, done);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(String current) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.dmGroupRename),
        content: TextField(
          key: GroupInfoScreen.renameFieldKey,
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: InputDecoration(labelText: l10n.dmGroupNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: GroupInfoScreen.renameSaveKey,
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: Text(l10n.dmGroupSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == current || !mounted) return;
    await _run(() async {
      await _repo.update(widget.groupId, name: name);
      invalidateDmBoxes(ref);
    });
  }

  Future<void> _photo(DmGroup group) async {
    final l10n = context.l10n;
    String? choice = 'pick';
    if (group.photoUrl != null) {
      choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.dmGroupChangePhoto),
                onTap: () => Navigator.of(sheet).pop('pick'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: sheet.palette.error),
                title: Text(l10n.dmGroupRemovePhoto),
                onTap: () => Navigator.of(sheet).pop('remove'),
              ),
            ],
          ),
        ),
      );
    }
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      await _run(() async {
        await _repo.update(widget.groupId, removePhoto: true);
        invalidateDmBoxes(ref);
      });
      return;
    }
    final picked = await ref.read(photoPickerProvider).pickPhotos(1);
    if (!mounted || picked.isEmpty) return;
    final bytes = picked.first;
    final type = sniffImageType(bytes);
    if (type == null) {
      KSnack.error(context, l10n.createPhotoUnsupported);
      return;
    }
    if (bytes.length > maxPhotoBytes) {
      KSnack.error(context, l10n.createPhotoTooLarge);
      return;
    }
    await _run(() async {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadDmGroupPhoto(bytes, type);
      await _repo.update(widget.groupId, photoMediaId: asset.id);
      invalidateDmBoxes(ref);
    });
  }

  Future<void> _memberActions(DmGroupMember m) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.dmViewProfile),
              onTap: () => Navigator.of(sheet).pop('profile'),
            ),
            if (m.role == DmGroupRole.member)
              ListTile(
                key: GroupInfoScreen.makeAdminKey,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(l10n.dmGroupMakeAdmin),
                onTap: () => Navigator.of(sheet).pop('admin'),
              )
            else
              ListTile(
                key: GroupInfoScreen.removeAdminKey,
                leading: const Icon(Icons.remove_moderator_outlined),
                title: Text(l10n.dmGroupRemoveAdmin),
                onTap: () => Navigator.of(sheet).pop('member'),
              ),
            ListTile(
              key: GroupInfoScreen.removeKey,
              leading: Icon(
                Icons.person_remove_outlined,
                color: sheet.palette.error,
              ),
              title: Text(
                l10n.dmGroupRemoveMember,
                style: TextStyle(color: sheet.palette.error),
              ),
              onTap: () => Navigator.of(sheet).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final username = m.user.username;
    switch (action) {
      case 'profile':
        unawaited(context.push(AppRoutes.userProfile(username)));
      case 'admin':
        await _run(
          () => _repo.setRole(widget.groupId, username, DmGroupRole.admin),
        );
      case 'member':
        await _run(
          () => _repo.setRole(widget.groupId, username, DmGroupRole.member),
        );
      case 'remove':
        await _run(() => _repo.removeMember(widget.groupId, username));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final g = widget.detail.group;
    final me = ref.watch(currentUserProvider.select((u) => u?.id));
    final admin = g.isAdmin;
    return ListView(
      padding: const EdgeInsets.only(bottom: KSpacing.xl),
      children: [
        const SizedBox(height: KSpacing.lg),
        Center(
          child: Semantics(
            button: admin,
            label: admin ? l10n.dmGroupChangePhoto : l10n.dmGroupPhoto,
            child: InkWell(
              key: GroupInfoScreen.photoKey,
              customBorder: const CircleBorder(),
              onTap: admin && !_busy ? () => unawaited(_photo(g)) : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DmGroupAvatar(name: g.name, photoUrl: g.photoUrl, size: 96),
                  if (admin)
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: p.primary,
                        child: Icon(
                          Icons.photo_camera_outlined,
                          size: 16,
                          color: p.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: KSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  g.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
              ),
              if (admin)
                IconButton(
                  key: GroupInfoScreen.renameKey,
                  tooltip: l10n.dmGroupRename,
                  onPressed: _busy ? null : () => unawaited(_rename(g.name)),
                  icon: Icon(Icons.edit_outlined, color: p.textSecondary),
                ),
            ],
          ),
        ),
        Text(
          l10n.dmGroupMembersCount(KFormat.compact(g.memberCount, l10n)),
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: KSpacing.md),
        Divider(color: p.border),
        SwitchListTile(
          key: GroupInfoScreen.muteKey,
          value: g.muted,
          onChanged: _busy
              ? null
              : (v) => unawaited(
                  _run(
                    () => _repo.setMuted(widget.groupId, muted: v),
                    done: v ? l10n.dmMuted : l10n.dmUnmuted,
                  ),
                ),
          secondary: const Icon(Icons.volume_off_outlined),
          title: Text(l10n.dmMute),
        ),
        SwitchListTile(
          key: GroupInfoScreen.archiveKey,
          value: g.archived,
          onChanged: _busy
              ? null
              : (v) => unawaited(
                  _run(() async {
                    await _repo.setArchived(widget.groupId, archived: v);
                    invalidateDmBoxes(ref);
                  }, done: v ? l10n.dmArchivedDone : l10n.dmUnarchivedDone),
                ),
          secondary: const Icon(Icons.archive_outlined),
          title: Text(l10n.dmArchive),
        ),
        Divider(color: p.border),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              l10n.dmGroupMembers,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
          ),
        ),
        if (admin && g.memberCount < widget.detail.maxMembers)
          ListTile(
            key: GroupInfoScreen.addKey,
            leading: CircleAvatar(
              backgroundColor: p.primary.withValues(alpha: 0.12),
              child: Icon(Icons.person_add_alt_1_outlined, color: p.primary),
            ),
            title: Text(l10n.dmGroupAddMembers),
            onTap: _busy
                ? null
                : () => unawaited(
                    context.push(AppRoutes.groupAdd(widget.groupId)),
                  ),
          ),
        for (final m in widget.detail.members)
          ListTile(
            key: GroupInfoScreen.memberKey(m.user.username),
            leading: KAvatar(
              name: m.user.displayName,
              imageUrl: m.user.avatarUrl,
              size: KSizes.avatarSm,
            ),
            title: Text(
              m.user.id == me ? l10n.dmGroupYou : m.user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // The handle reads left to right at the reading start.

            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,

              child: Text(
                '@${m.user.username}',

                maxLines: 1,

                textDirection: TextDirection.ltr,

                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: m.role == DmGroupRole.admin
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(KRadius.pill),
                    ),
                    child: Text(
                      m.creator ? l10n.dmGroupCreator : l10n.dmGroupAdmin,
                      style: t.caption.copyWith(
                        color: p.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
            onTap: _busy
                ? null
                : admin && !m.creator && m.user.id != me
                ? () => unawaited(_memberActions(m))
                : () => unawaited(
                    context.push(AppRoutes.userProfile(m.user.username)),
                  ),
          ),
        Divider(color: p.border),
        ListTile(
          key: GroupInfoScreen.reportKey,
          leading: const Icon(Icons.flag_outlined),
          title: Text(l10n.dmGroupReport),
          onTap: _busy
              ? null
              : () async {
                  final reason = await pickReportReason(
                    context,
                    l10n.dmGroupReport,
                  );
                  if (reason == null || !context.mounted) return;
                  await _run(
                    () => _repo.report(widget.groupId, reason),
                    done: l10n.dmReported,
                  );
                },
        ),
        ListTile(
          key: GroupInfoScreen.leaveKey,
          leading: Icon(Icons.logout_rounded, color: p.error),
          title: Text(l10n.dmGroupLeave, style: TextStyle(color: p.error)),
          onTap: _busy
              ? null
              : () async {
                  final ok = await confirmLeaveGroup(context);
                  if (!ok || !context.mounted) return;
                  try {
                    await _repo.leave(widget.groupId);
                    invalidateDmBoxes(ref);
                    unawaited(ref.read(dmUnreadProvider.notifier).refresh());
                    if (context.mounted) context.go(AppRoutes.messages);
                  } on Object catch (e) {
                    if (context.mounted) {
                      KSnack.error(
                        context,
                        failureMessage(l10n, toAppFailure(e)),
                      );
                    }
                  }
                },
        ),
      ],
    );
  }
}
