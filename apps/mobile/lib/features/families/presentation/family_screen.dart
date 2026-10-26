import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/families/presentation/families_screen.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/profile/profile_screen.dart'
    show PostGridLoadMore;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/families/:familyId` (CP-018, §10.21): the emblem, name, number, level
/// and progress to the next level; Ask to join / Cancel / Leave by the
/// caller's state; pending join requests for the leader and deputies
/// (accept, decline); the members with their roles. The leader also sets
/// roles, removes members, hands the family over, changes the emblem and
/// disbands a family that has only them.
class FamilyScreen extends ConsumerWidget {
  const new({required this.familyId, super.key});

  final String familyId;

  static const joinKey = Key('family.join');
  static const cancelKey = Key('family.cancelRequest');
  static const leaveKey = Key('family.leave');
  static const manageKey = Key('family.manage');
  static const disbandKey = Key('family.disband');
  static const changeEmblemKey = Key('family.changeEmblem');
  static const removeEmblemKey = Key('family.removeEmblem');
  static const notFoundKey = Key('family.notFound');
  static const requestsKey = Key('family.requests');

  static Key memberKey(String username) => Key('family.member.$username');
  static Key memberMenuKey(String username) =>
      Key('family.member.$username.menu');
  static Key acceptKey(String requestId) => Key('family.request.$requestId.ok');
  static Key declineKey(String requestId) =>
      Key('family.request.$requestId.no');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(familyProvider(familyId));
    final family = load.value;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(family?.name ?? l10n.familiesTitle),
        actions: [
          if (family?.myRole == FamilyRole.leader) _LeaderMenu(family: family!),
        ],
      ),
      body: switch (load) {
        AsyncValue(:final value?) => _FamilyBody(family: value),
        AsyncValue(:final error?, isLoading: false)
            when isErrorCode(error, ErrorCode.notFound) =>
          Center(
            key: notFoundKey,
            child: KEmptyState(
              icon: Icons.groups_2_outlined,
              title: l10n.familyNotFoundTitle,
              message: l10n.familyNotFoundBody,
            ),
          ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.familyLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(familyProvider(familyId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

enum _Manage { changeEmblem, removeEmblem, disband }

class _LeaderMenu extends ConsumerWidget {
  const new({required this.family});

  final Family family;

  Future<void> _changeEmblem(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final picked = await ref.read(photoPickerProvider).pickPhotos(1);
    if (!context.mounted || picked.isEmpty) return;
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
    try {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadFamilyEmblem(bytes, type);
      await ref.read(familiesRepositoryProvider).setEmblem(family.id, asset.id);
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyEmblemUpdated);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  Future<void> _removeEmblem(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref.read(familiesRepositoryProvider).setEmblem(family.id, null);
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyEmblemRemoved);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  Future<void> _disband(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmBond(
      context,
      title: l10n.familyDisbandTitle(family.name),
      body: l10n.familyDisbandBody,
      confirm: l10n.familyDisband,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(familiesRepositoryProvider).disband(family.id);
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyDisbanded);
      if (context.canPop()) context.pop();
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alone = family.memberCount <= 1;
    return PopupMenuButton<_Manage>(
      key: FamilyScreen.manageKey,
      tooltip: l10n.familyManage,
      icon: const Icon(Icons.tune_rounded),
      onSelected: (action) => unawaited(switch (action) {
        _Manage.changeEmblem => _changeEmblem(context, ref),
        _Manage.removeEmblem => _removeEmblem(context, ref),
        _Manage.disband => _disband(context, ref),
      }),
      itemBuilder: (_) => [
        PopupMenuItem(
          key: FamilyScreen.changeEmblemKey,
          value: _Manage.changeEmblem,
          child: Text(l10n.familyChangeEmblem),
        ),
        if (family.emblemUrl != null)
          PopupMenuItem(
            key: FamilyScreen.removeEmblemKey,
            value: _Manage.removeEmblem,
            child: Text(l10n.familyRemoveEmblem),
          ),
        PopupMenuItem(
          key: FamilyScreen.disbandKey,
          value: _Manage.disband,
          enabled: alone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.familyDisband),
              if (!alone)
                Text(
                  l10n.familyDisbandOnlyAlone,
                  style: context.textStyles.caption,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilyBody extends ConsumerWidget {
  const new({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = family.myRole;
    final members = ref.watch(familyMembersProvider(family.id));
    final rows = <Widget>[
      _Header(family: family),
      _Actions(family: family),
      if (role != null && role.answersRequests)
        _Requests(key: FamilyScreen.requestsKey, family: family),
      BondSectionTitle(
        l10n.familyMembersTitle,
        trailing: Text(
          l10n.familyMembersCount(family.memberCount, family.capacity),
          style: context.textStyles.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ),
    ];
    final notifier = ref.read(familyMembersProvider(family.id).notifier);
    final Widget list = switch (members) {
      AsyncValue(:final value?) => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: KSpacing.xl),
        itemCount: rows.length + value.items.length + (value.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < rows.length) return rows[i];
          final j = i - rows.length;
          if (j < value.items.length) {
            return _MemberTile(family: family, member: value.items[j]);
          }
          return value.loadMoreError == null
              ? PostGridLoadMore(
                  key: ValueKey(value.items.length),
                  onVisible: () => unawaited(notifier.loadMore()),
                )
              : Center(
                  child: TextButton(
                    onPressed: () => unawaited(notifier.loadMore()),
                    child: Text(l10n.actionRetry),
                  ),
                );
        },
      ),
      AsyncValue(:final error?, isLoading: false) => ListView(
        children: [
          ...rows,
          FailureErrorState(
            title: l10n.familyLoadError,
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(familyMembersProvider(family.id)),
            compact: true,
          ),
        ],
      ),
      _ => ListView(
        children: [
          ...rows,
          const Padding(
            padding: EdgeInsets.all(KSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    };
    return RefreshIndicator(
      onRefresh: () async {
        refreshFamilies(ref, familyId: family.id);
        await ref.read(familyProvider(family.id).future);
      },
      child: list,
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final next = family.nextLevelPoints;
    final leader = family.leader;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.md,
        KSpacing.lg,
        KSpacing.sm,
      ),
      child: Column(
        children: [
          FamilyEmblem(url: family.emblemUrl, size: 88),
          const SizedBox(height: KSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    family.name,
                    textAlign: TextAlign.center,
                    style: t.title.copyWith(color: p.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              FamilyLevelChip(level: family.level),
            ],
          ),
          InkWell(
            borderRadius: BorderRadius.circular(KRadius.pill),
            onTap: () {
              unawaited(
                Clipboard.setData(ClipboardData(text: '${family.number}')),
              );
              KSnack.info(context, l10n.profileCopied);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.sm,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.familyNumber('${family.number}'),
                      style: t.body.copyWith(color: p.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.copy_rounded, size: 14, color: p.textSecondary),
                ],
              ),
            ),
          ),
          if (leader != null)
            Text(
              l10n.familyLeader(
                leader.displayName.isEmpty
                    ? leader.username
                    : leader.displayName,
              ),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          const SizedBox(height: KSpacing.md),
          if (next != null) ...[
            BondProgress(
              value: next <= 0 ? 1 : family.points / next,
              color: const Color(0xFFD9922E),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.familyProgress(
                formatBondPoints(family.points),
                formatBondPoints(next),
                family.level + 1,
              ),
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ] else
            Text(
              '${l10n.familyTopLevel} · '
              '${l10n.familyPoints(formatBondPoints(family.points))}',
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// Ask to join, Cancel the request, or Leave, by the caller's state.
class _Actions extends ConsumerStatefulWidget {
  const new({required this.family});

  final Family family;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _busy = false;

  Family get family => widget.family;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final l10n = context.l10n;
    final repo = ref.read(familiesRepositoryProvider);
    void joined() {
      if (!mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyJoinSent);
    }

    var pendingElsewhere = false;
    await _run(() async {
      try {
        await repo.requestToJoin(family.id);
      } on Object catch (e) {
        if (!isErrorCode(e, ErrorCode.familyRequestPending)) rethrow;
        pendingElsewhere = true;
        return;
      }
      joined();
    });
    if (!pendingElsewhere || !mounted) return;
    // One pending request at a time: offer to cancel the other one.
    final cancel = await confirmBond(
      context,
      title: l10n.errorFamilyRequestPending,
      confirm: l10n.familyCancelRequest,
    );
    if (!cancel || !mounted) return;
    await _run(() async {
      await repo.cancelMyRequest();
      await repo.requestToJoin(family.id);
      joined();
    });
  }

  Future<void> _cancel() => _run(() async {
    await ref.read(familiesRepositoryProvider).cancelMyRequest();
    if (!mounted) return;
    refreshFamilies(ref, familyId: family.id);
    KSnack.success(context, context.l10n.familyRequestCancelled);
  });

  Future<void> _leave() async {
    final l10n = context.l10n;
    final ok = await confirmBond(
      context,
      title: l10n.familyLeaveTitle(family.name),
      body: l10n.familyLeaveBody,
      confirm: l10n.familyLeave,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await ref.read(familiesRepositoryProvider).leave(family.id);
      if (!mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyLeft);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final role = family.myRole;
    final mine = ref.watch(myFamilyProvider).value;
    final Widget child;
    if (role == FamilyRole.leader) {
      // The leader hands over or disbands instead of leaving (§10.21).
      return const SizedBox(height: KSpacing.sm);
    } else if (role != null) {
      child = KButton(
        key: FamilyScreen.leaveKey,
        label: l10n.familyLeave,
        variant: KButtonVariant.secondary,
        loading: _busy,
        onPressed: _leave,
      );
    } else if (family.myRequestId != null) {
      child = Column(
        children: [
          Text(
            l10n.familyRequested,
            style: context.textStyles.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.xs),
          KButton(
            key: FamilyScreen.cancelKey,
            label: l10n.familyCancelRequest,
            variant: KButtonVariant.secondary,
            loading: _busy,
            onPressed: _cancel,
          ),
        ],
      );
    } else if (mine != null) {
      child = KInlineMessage(message: l10n.familyInOther, isError: false);
    } else {
      child = KButton(
        key: FamilyScreen.joinKey,
        label: family.isFull ? l10n.familyFullLabel : l10n.familyJoin,
        loading: _busy,
        onPressed: family.isFull ? null : _join,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.sm,
        KSpacing.lg,
        0,
      ),
      child: child,
    );
  }
}

/// Pending join requests (the leader and deputies), with Accept and
/// Decline.
class _Requests extends ConsumerWidget {
  const new({required this.family, super.key});

  final Family family;

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    FamilyJoinRequest request, {
    required bool accept,
  }) async {
    final l10n = context.l10n;
    final repo = ref.read(familiesRepositoryProvider);
    final name = request.user.displayName.isEmpty
        ? request.user.username
        : request.user.displayName;
    try {
      if (accept) {
        await repo.acceptRequest(family.id, request.id);
      } else {
        await repo.declineRequest(family.id, request.id);
      }
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(
        context,
        accept ? l10n.familyAccepted(name) : l10n.familyDeclined,
      );
    } on Object catch (e) {
      if (!context.mounted) return;
      // Already answered, expired, or they joined elsewhere: the list
      // shows what is left.
      if (isErrorCode(e, ErrorCode.familyRequestNotPending) ||
          isErrorCode(e, ErrorCode.alreadyInFamily)) {
        ref
            .read(familyJoinRequestsProvider(family.id).notifier)
            .remove(request.id);
      }
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final load = ref.watch(familyJoinRequestsProvider(family.id));
    final items = switch (load) {
      AsyncValue(value: FeedItems(:final items)) => items,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BondSectionTitle(l10n.familyRequestsTitle),
        if (items == null && load.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: KInlineMessage(
              message: failureMessage(l10n, toAppFailure(load.error!)),
            ),
          )
        else if (items == null)
          const Padding(
            padding: EdgeInsets.all(KSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Text(
              l10n.familyRequestsEmpty,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          )
        else
          for (final r in items)
            ListTile(
              leading: KAvatar(
                name: r.user.displayName.isEmpty
                    ? r.user.username
                    : r.user.displayName,
                imageUrl: r.user.avatarUrl,
                size: 40,
              ),
              title: Text(
                r.user.displayName.isEmpty
                    ? r.user.username
                    : r.user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                l10n.profileUsername(r.user.username),
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => context.push(AppRoutes.userProfile(r.user.username)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: FamilyScreen.declineKey(r.id),
                    tooltip: l10n.familyDecline,
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                    onPressed: () =>
                        unawaited(_answer(context, ref, r, accept: false)),
                  ),
                  IconButton(
                    key: FamilyScreen.acceptKey(r.id),
                    tooltip: l10n.familyAccept,
                    icon: Icon(Icons.check_circle_rounded, color: p.success),
                    onPressed: () =>
                        unawaited(_answer(context, ref, r, accept: true)),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

enum _MemberAction { deputy, member, transfer, remove }

class _MemberTile extends ConsumerWidget {
  const new({required this.family, required this.member});

  final Family family;
  final FamilyMember member;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    _MemberAction action,
  ) async {
    final l10n = context.l10n;
    final repo = ref.read(familiesRepositoryProvider);
    final user = member.user;
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    try {
      switch (action) {
        case _MemberAction.deputy || _MemberAction.member:
          await repo.setRole(
            family.id,
            user.username,
            action == _MemberAction.deputy
                ? FamilyRole.deputy
                : FamilyRole.member,
          );
          if (context.mounted) {
            KSnack.success(context, l10n.familyRoleChanged(name));
          }
        case _MemberAction.transfer:
          final ok = await confirmBond(
            context,
            title: l10n.familyTransferTitle(name),
            body: l10n.familyTransferBody(name),
            confirm: l10n.familyTransfer,
          );
          if (!ok) return;
          await repo.transfer(family.id, user.username);
          if (context.mounted) {
            KSnack.success(context, l10n.familyTransferred(name));
          }
        case _MemberAction.remove:
          final ok = await confirmBond(
            context,
            title: l10n.familyRemoveTitle(name),
            confirm: l10n.familyRemove,
            destructive: true,
          );
          if (!ok) return;
          await repo.removeMember(family.id, user.username);
          if (context.mounted) {
            KSnack.success(context, l10n.familyRemoved(name));
          }
      }
      if (context.mounted) refreshFamilies(ref, familyId: family.id);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final user = member.user;
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    final manage =
        family.myRole == FamilyRole.leader && member.role != FamilyRole.leader;
    final roleLabel = switch (member.role) {
      FamilyRole.leader => l10n.familyRoleLeader,
      FamilyRole.deputy => l10n.familyRoleDeputy,
      FamilyRole.member => l10n.familyRoleMember,
    };
    return ListTile(
      key: FamilyScreen.memberKey(user.username),
      leading: KAvatar(name: name, imageUrl: user.avatarUrl, size: 40),
      title: Row(
        children: [
          Flexible(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (member.role != FamilyRole.member) ...[
            const SizedBox(width: KSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: member.role == FamilyRole.leader
                    ? const Color(0xFFF2B84B)
                    : p.surfaceRaised,
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
              child: Text(
                roleLabel,
                style: t.caption.copyWith(
                  color: member.role == FamilyRole.leader
                      ? const Color(0xFF3A2500)
                      : p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        l10n.familyPoints(formatBondPoints(member.points)),
        style: t.caption.copyWith(color: p.textSecondary),
      ),
      onTap: () => context.push(AppRoutes.userProfile(user.username)),
      trailing: manage
          ? PopupMenuButton<_MemberAction>(
              key: FamilyScreen.memberMenuKey(user.username),
              tooltip: l10n.familyMemberActions,
              onSelected: (a) => unawaited(_act(context, ref, a)),
              itemBuilder: (_) => [
                if (member.role == FamilyRole.member)
                  PopupMenuItem(
                    value: _MemberAction.deputy,
                    child: Text(l10n.familyMakeDeputy),
                  )
                else
                  PopupMenuItem(
                    value: _MemberAction.member,
                    child: Text(l10n.familyMakeMember),
                  ),
                PopupMenuItem(
                  value: _MemberAction.transfer,
                  child: Text(l10n.familyTransfer),
                ),
                PopupMenuItem(
                  value: _MemberAction.remove,
                  child: Text(
                    l10n.familyRemove,
                    style: TextStyle(color: p.error),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
