import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The caller's privacy settings (`GET`/`PATCH /me/privacy`). A change is
/// sent at once and the screen shows what the server kept.
class PrivacyController extends AsyncNotifier<PrivacySettings> {
  @override
  Future<PrivacySettings> build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    return ref.watch(safetyRepositoryProvider).privacy();
  }

  /// Sends the change; throws its `AppFailure` and keeps the old value.
  Future<void> change({
    MentionPolicy? whoCanMention,
    WhoCanComment? defaultWhoCanComment,
  }) async {
    final next = await ref
        .read(safetyRepositoryProvider)
        .updatePrivacy(
          whoCanMention: whoCanMention,
          defaultWhoCanComment: defaultWhoCanComment,
        );
    if (ref.mounted) state = AsyncData(next);
  }
}

final AsyncNotifierProvider<PrivacyController, PrivacySettings>
privacyProvider =
    AsyncNotifierProvider.autoDispose<PrivacyController, PrivacySettings>(
      PrivacyController.new,
    );

/// `/settings/privacy` (KL-060): who can mention you, and who can comment
/// on your new posts by default (CONVENTIONS §11.7).
class PrivacyScreen extends ConsumerWidget {
  const new({super.key});

  static Key mentionKey(MentionPolicy p) => Key('privacy.mention.${p.name}');
  static Key commentKey(WhoCanComment w) => Key('privacy.comment.${w.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final privacy = ref.watch(privacyProvider);
    Future<void> save(Future<void> Function() change) async {
      try {
        await change();
        if (context.mounted) KSnack.success(context, l10n.privacySaved);
      } on Object catch (e) {
        if (context.mounted) {
          KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
        }
      }
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.xs,
      ),
      child: Text(
        text,
        style: context.textStyles.bodyStrong.copyWith(color: p.textPrimary),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyPrivacy)),
      body: switch (privacy) {
        AsyncValue(:final value?) => ListView(
          children: [
            header(l10n.privacyMentionTitle),
            RadioGroup<MentionPolicy>(
              groupValue: value.whoCanMention,
              onChanged: (v) {
                if (v == null || v == value.whoCanMention) return;
                unawaited(
                  save(
                    () => ref
                        .read(privacyProvider.notifier)
                        .change(whoCanMention: v),
                  ),
                );
              },
              child: Column(
                children: [
                  for (final (m, label) in [
                    (MentionPolicy.everyone, l10n.privacyMentionEveryone),
                    (MentionPolicy.following, l10n.privacyMentionFollowing),
                    (MentionPolicy.nobody, l10n.privacyMentionNobody),
                  ])
                    RadioListTile<MentionPolicy>(
                      key: mentionKey(m),
                      value: m,
                      title: Text(label),
                    ),
                ],
              ),
            ),
            header(l10n.privacyCommentTitle),
            RadioGroup<WhoCanComment>(
              groupValue: value.defaultWhoCanComment,
              onChanged: (v) {
                if (v == null || v == value.defaultWhoCanComment) return;
                unawaited(
                  save(
                    () => ref
                        .read(privacyProvider.notifier)
                        .change(defaultWhoCanComment: v),
                  ),
                );
              },
              child: Column(
                children: [
                  for (final (w, label) in [
                    (WhoCanComment.everyone, l10n.createWhoEveryone),
                    (WhoCanComment.followers, l10n.createWhoFollowers),
                    (WhoCanComment.nobody, l10n.createWhoNobody),
                  ])
                    RadioListTile<WhoCanComment>(
                      key: commentKey(w),
                      value: w,
                      title: Text(label),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: Text(
                l10n.privacyCommentHint,
                style: context.textStyles.caption.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ],
        ),
        AsyncError(:final error) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(privacyProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// The accounts the caller blocked (`GET /me/blocks`), paged, with
/// Unblock.
class BlockedAccounts extends AsyncNotifier<FeedItems<UserSummary>> {
  String? _next;

  @override
  Future<FeedItems<UserSummary>> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id));
    final page = await ref.watch(safetyRepositoryProvider).blocks();
    _next = page.next;
    return FeedItems(page.items, hasMore: _next != null);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await ref
          .read(safetyRepositoryProvider)
          .blocks(cursor: _next);
      if (!ref.mounted) return;
      _next = page.next;
      final known = {for (final u in s.items) u.id};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final u in page.items)
            if (!known.contains(u.id)) u,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }

  /// Unblocks [user] (follows are not restored) and drops them from the
  /// list; throws its `AppFailure` and keeps them when it fails.
  Future<void> unblock(UserSummary user) async {
    await ref
        .read(safetyRepositoryProvider)
        .setBlocked(user.username, blocked: false);
    ref.invalidate(postsFeedProvider);
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(
      FeedItems([
        for (final u in s.items)
          if (u.id != user.id) u,
      ], hasMore: s.hasMore),
    );
  }
}

final AsyncNotifierProvider<BlockedAccounts, FeedItems<UserSummary>>
blockedAccountsProvider =
    AsyncNotifierProvider.autoDispose<BlockedAccounts, FeedItems<UserSummary>>(
      BlockedAccounts.new,
    );

/// `/settings/blocked` (KL-060): who you blocked, newest first; Unblock
/// asks nothing (blocking again is one tap away on their profile).
class BlockedAccountsScreen extends ConsumerWidget {
  const new({super.key});

  static const emptyKey = Key('blocked.empty');
  static Key unblockKey(String username) => Key('blocked.$username.unblock');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final blocked = ref.watch(blockedAccountsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyBlockedAccounts)),
      body: switch (blocked) {
        AsyncValue(value: FeedItems(:final items)) when items.isEmpty =>
          KEmptyState(
            key: emptyKey,
            icon: Icons.block_rounded,
            title: l10n.safetyNoBlocked,
            message: l10n.safetyNoBlockedBody,
          ),
        AsyncValue(value: FeedItems(:final items, :final hasMore)) =>
          ListView.builder(
            itemCount: items.length + (hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == items.length) {
                return PostGridLoadMore(
                  key: ValueKey(items.length),
                  onVisible: () =>
                      ref.read(blockedAccountsProvider.notifier).loadMore(),
                );
              }
              final u = items[i];
              final name = u.displayName.isEmpty ? u.username : u.displayName;
              return ListTile(
                leading: ExcludeSemantics(
                  child: KAvatar(name: name, imageUrl: u.avatarUrl),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  l10n.profileUsername(u.username),
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  textAlign: Directionality.of(context) == TextDirection.rtl
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                trailing: OutlinedButton(
                  key: unblockKey(u.username),
                  style: profileSecondaryButtonStyle(context),
                  onPressed: () async {
                    try {
                      await ref
                          .read(blockedAccountsProvider.notifier)
                          .unblock(u);
                      if (context.mounted) {
                        KSnack.success(context, l10n.safetyUnblocked(name));
                      }
                    } on Object catch (e) {
                      if (context.mounted) {
                        KSnack.error(
                          context,
                          failureMessage(l10n, toAppFailure(e)),
                        );
                      }
                    }
                  },
                  child: Text(l10n.safetyUnblock),
                ),
                onTap: () => context.push(AppRoutes.userProfile(u.username)),
              );
            },
          ),
        AsyncError(:final error) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(blockedAccountsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
