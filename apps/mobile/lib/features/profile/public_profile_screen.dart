import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/users/:username` (D60): another user's public profile, from
/// `GET /users/{username}` (v1.3), in the layout of the own profile (D57):
///
/// - top bar: back, @username in the centre, and the three dots (D62):
///   copy the username, mute, block and report (KL-060, §11.7); copy link
///   (needs the production domain, B7) is shown as "Coming soon";
/// - the header (photo, Followers and Following, name, bio). While the user
///   is live the photo has the live ring and badge, and tapping it opens
///   the room;
/// - Follow (red) or Following (grey; asks before unfollowing), through the
///   follow API with the optimistic [PublicProfileController]; beside it,
///   Message and, while the user is live, a compact LIVE button. D175:
///   following a private account sends a request ("Requested", tap to
///   cancel). Your own
///   username shows "Edit profile" instead. **Message** (D61) opens the
///   conversation screen, which is not connected until a messaging API
///   exists;
/// - Posts, Reels and Reposts tabs over the grid (no Saved: it is
///   private), or "This account is private" for a private account you do
///   not follow;
/// - a missing account (404) gets its own state, other failures the error
///   state with Try again.
class PublicProfileScreen extends ConsumerStatefulWidget {
  const new({required this.username, super.key});

  final String username;

  static const followKey = Key('profile.public.follow');
  static const watchLiveKey = Key('profile.public.watchLive');
  static const messageKey = Key('profile.public.message');
  static const moreKey = Key('profile.public.more');
  static const copyUsernameKey = Key('profile.public.copyUsername');
  static const copyLinkKey = Key('profile.public.copyLink');
  static const reportKey = Key('profile.public.report');
  static const muteKey = Key('profile.public.mute');
  static const unmuteKey = Key('profile.public.unmute');
  static const blockKey = Key('profile.public.block');
  static const unfollowKey = Key('profile.public.unfollow');
  static const cancelRequestKey = Key('profile.public.cancelRequest');
  static const privateKey = Key('profile.public.private');
  static const notFoundKey = Key('profile.public.notFound');

  static const List<ProfileTab> tabs = [
    ProfileTab.posts,
    ProfileTab.reels,
    ProfileTab.reposts,
  ];

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

enum _More { copy, mute, unmute, block, report }

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  ProfileTab _tab = ProfileTab.posts;

  Future<void> _setFollowing({required bool follow}) async {
    try {
      await ref
          .read(publicProfileProvider(widget.username).notifier)
          .setFollowing(follow: follow);
      // D175: a private account gets a request; say so.
      final now = ref.read(publicProfileProvider(widget.username)).value;
      if (follow && mounted && (now?.followRequested ?? false)) {
        KSnack.success(context, context.l10n.profileRequestSent);
      }
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    }
  }

  /// D175: cancelling a pending follow request asks first.
  Future<void> _confirmCancelRequest(PublicProfile profile) async {
    final l10n = context.l10n;
    final cancel = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Text(
                l10n.profileCancelRequestConfirm(profile.displayName),
                textAlign: TextAlign.center,
                style: sheet.textStyles.bodyStrong,
              ),
            ),
            ListTile(
              key: PublicProfileScreen.cancelRequestKey,
              title: Text(
                l10n.profileCancelRequest,
                textAlign: TextAlign.center,
                style: TextStyle(color: sheet.palette.error),
              ),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
          ],
        ),
      ),
    );
    if (cancel ?? false) await _setFollowing(follow: false);
  }

  Future<void> _confirmUnfollow(PublicProfile profile) async {
    final l10n = context.l10n;
    final unfollow = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Text(
                l10n.profileUnfollowConfirm(profile.displayName),
                textAlign: TextAlign.center,
                style: sheet.textStyles.bodyStrong,
              ),
            ),
            ListTile(
              key: PublicProfileScreen.unfollowKey,
              title: Text(
                l10n.homeUnfollowAuthor(profile.displayName),
                textAlign: TextAlign.center,
                style: TextStyle(color: sheet.palette.error),
              ),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
          ],
        ),
      ),
    );
    if (unfollow ?? false) await _setFollowing(follow: false);
  }

  /// D62: the three dots: copy the username; mute, block and report the
  /// account (CONVENTIONS §11.7). Copying the profile link waits for the
  /// production domain (B7) and is shown as "Coming soon".
  Future<void> _openMore(PublicProfile profile) async {
    final l10n = context.l10n;
    final name = profile.displayName.isEmpty
        ? profile.username
        : profile.displayName;
    final action = await showModalBottomSheet<_More>(
      context: context,
      builder: (sheet) {
        final p = sheet.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: PublicProfileScreen.copyUsernameKey,
                leading: Icon(
                  Icons.alternate_email_rounded,
                  color: p.textPrimary,
                ),
                title: Text(l10n.profileCopyUsername),
                onTap: () => Navigator.of(sheet).pop(_More.copy),
              ),
              ListTile(
                key: PublicProfileScreen.copyLinkKey,
                enabled: false,
                leading: Icon(Icons.link_rounded, color: p.textTertiary),
                title: Text(l10n.profileCopyLink),
                trailing: Text(
                  l10n.profileEditSoon,
                  style: sheet.textStyles.caption.copyWith(
                    color: p.textTertiary,
                  ),
                ),
              ),
              if (!profile.isSelf) ...[
                // CP-007: the profile says whether you muted them.
                if (profile.isMuted)
                  ListTile(
                    key: PublicProfileScreen.unmuteKey,
                    leading: Icon(
                      Icons.volume_up_outlined,
                      color: p.textPrimary,
                    ),
                    title: Text(l10n.safetyUnmuteUser(name)),
                    onTap: () => Navigator.of(sheet).pop(_More.unmute),
                  )
                else
                  ListTile(
                    key: PublicProfileScreen.muteKey,
                    leading: Icon(
                      Icons.volume_off_outlined,
                      color: p.textPrimary,
                    ),
                    title: Text(l10n.safetyMuteUser(name)),
                    onTap: () => Navigator.of(sheet).pop(_More.mute),
                  ),
                ListTile(
                  key: PublicProfileScreen.blockKey,
                  leading: Icon(Icons.block_rounded, color: p.error),
                  title: Text(
                    l10n.safetyBlockUser(name),
                    style: TextStyle(color: p.error),
                  ),
                  onTap: () => Navigator.of(sheet).pop(_More.block),
                ),
                ListTile(
                  key: PublicProfileScreen.reportKey,
                  leading: Icon(Icons.flag_outlined, color: p.error),
                  title: Text(
                    l10n.safetyReportUser,
                    style: TextStyle(color: p.error),
                  ),
                  onTap: () => Navigator.of(sheet).pop(_More.report),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _More.copy:
        await Clipboard.setData(
          // D158: what is shown is copied (a premium username has no «@»).
          ClipboardData(
            text: KHandle.plain(
              profile.username,
              premiumTier: profile.premiumTier,
            ),
          ),
        );
        if (mounted) KSnack.success(context, l10n.profileCopied);
      case _More.mute:
        await muteUser(context, ref, username: profile.username, name: name);
      case _More.unmute:
        await unmuteUser(context, ref, username: profile.username, name: name);
      case _More.block:
        final blocked = await confirmBlock(
          context,
          ref,
          username: profile.username,
          name: name,
        );
        // Their profile is no longer visible: back to where you came from.
        if (blocked && mounted && context.canPop()) context.pop();
      case _More.report:
        await reportUser(context, ref, userId: profile.id);
    }
  }

  Widget _actions(PublicProfile profile) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    if (profile.isSelf) {
      return SizedBox(
        height: KProfile.buttonHeight,
        child: OutlinedButton(
          style: profileSecondaryButtonStyle(context),
          onPressed: () => context.push(AppRoutes.editProfile),
          child: Text(l10n.profileEditTitle),
        ),
      );
    }
    final follow = profile.isFollowing
        ? OutlinedButton(
            key: PublicProfileScreen.followKey,
            style: profileSecondaryButtonStyle(context),
            onPressed: () => _confirmUnfollow(profile),
            child: Text(l10n.liveFollowing),
          )
        : profile.followRequested
        // D175: a request to a private account waits for its answer.
        ? OutlinedButton(
            key: PublicProfileScreen.followKey,
            style: profileSecondaryButtonStyle(context),
            onPressed: () => _confirmCancelRequest(profile),
            child: Text(l10n.followRequested),
          )
        : FilledButton(
            key: PublicProfileScreen.followKey,
            style: FilledButton.styleFrom(
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KRadius.sm),
              ),
              textStyle: t.bodyStrong,
            ),
            // D175: a private account gets a follow request (§10.43).
            onPressed: profile.canFollowOrRequest
                ? () => _setFollowing(follow: true)
                : null,
            child: Text(l10n.liveFollow),
          );
    final room = profile.liveRoomId;
    return SizedBox(
      height: KProfile.buttonHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: follow),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: OutlinedButton(
              key: PublicProfileScreen.messageKey,
              style: profileSecondaryButtonStyle(context),
              onPressed: () => context.push(
                AppRoutes.chat(profile.username),
                extra: (
                  displayName: profile.displayName,
                  premiumTier: profile.premiumTier,
                ),
              ),
              child: Text(l10n.profileMessage),
            ),
          ),
          if (room != null) ...[
            const SizedBox(width: KSpacing.sm),
            // Compact while live: Follow and Message keep the width.
            Semantics(
              label: l10n.profileWatchLive,
              button: true,
              excludeSemantics: true,
              child: OutlinedButton.icon(
                key: PublicProfileScreen.watchLiveKey,
                style: profileSecondaryButtonStyle(context),
                onPressed: () => context.push(AppRoutes.liveRoom(room)),
                icon: Container(
                  width: KSpacing.sm,
                  height: KSpacing.sm,
                  decoration: const BoxDecoration(
                    color: KLiveColors.badge,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(l10n.liveBadge),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(publicProfileProvider(widget.username));
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        // D146: a premium username wears its special-ID badge.
        title: switch (load.value?.premiumTier) {
          final tier? => KSpecialUsername(
            username: load.value!.username,
            tier: tier,
            height: 24,
          ),
          null => Text(
            l10n.profileUsername(widget.username),
            textDirection: TextDirection.ltr,
            style: context.textStyles.title.copyWith(color: p.textPrimary),
          ),
        },
        actions: [
          IconButton(
            key: PublicProfileScreen.moreKey,
            tooltip: l10n.feedPostMore,
            // Needs the loaded profile (its id and whether it is you).
            onPressed: switch (load) {
              AsyncValue(:final value?) => () => _openMore(value),
              _ => null,
            },
            icon: AppIcon(
              AppIcons.moreHoriz,
              size: KMetrics.iconMd,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
      body: switch (load) {
        AsyncValue(:final value?) => _body(value),
        AsyncValue(:final error?, isLoading: false) when _notFound(error) =>
          Center(
            key: PublicProfileScreen.notFoundKey,
            child: KEmptyState(
              icon: Icons.person_off_outlined,
              title: l10n.profileNotFoundTitle,
              message: l10n.profileNotFoundBody,
            ),
          ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(publicProfileProvider(widget.username)),
        ),
        _ => const ProfileSkeleton(),
      },
    );
  }

  static bool _notFound(Object error) => switch (toAppFailure(error)) {
    ServerFailure(code: ErrorCode.notFound) => true,
    _ => false,
  };

  Widget _body(PublicProfile profile) {
    final l10n = context.l10n;
    final p = context.palette;
    final room = profile.liveRoomId;
    final locked = profile.locked;
    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(profileGridProvider);
        return ref.refresh(publicProfileProvider(widget.username).future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ProfileHeaderView(
              displayName: profile.displayName,
              avatarUrl: profile.avatarUrl,
              bio: profile.bio,
              followers: profile.followerCount,
              following: profile.followingCount,
              live: room != null,
              onOpenLive: room == null
                  ? null
                  : () => context.push(AppRoutes.liveRoom(room)),
              levels: ProfileBondsBlock(
                levels: ProfileLevels(
                  username: profile.isSelf ? null : profile.username,
                  onOpen: profile.isSelf
                      ? () => context.push(AppRoutes.levels)
                      : null,
                ),
                profile: profile,
              ),
              cpFrame: cpWearsSpecialFrame(profile.cp),
              // D175: the category (and a gender the person shows) under
              // the name; the links after the bio — on a private profile
              // too (the profile itself is public, §10.43).
              subtitle: ProfileFieldsLine(
                category: profile.category,
                gender: profile.gender,
              ),
              about: ProfileLinksRow(
                links: profile.links,
                reportable: !profile.isSelf,
              ),
              // D121: the lists; a private account's are its followers'
              // only, so a locked profile keeps the counts plain.
              onOpenFollowers: locked
                  ? null
                  : () => context.push(AppRoutes.userFollows(profile.username)),
              onOpenFollowing: locked
                  ? null
                  : () => context.push(
                      AppRoutes.userFollows(profile.username, following: true),
                    ),
              actions: _actions(profile),
            ),
          ),
          if (locked)
            SliverToBoxAdapter(
              child: Padding(
                key: PublicProfileScreen.privateKey,
                padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
                child: KEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.profilePrivateTitle,
                  message: l10n.profilePrivateBody,
                  compact: true,
                ),
              ),
            )
          else ...[
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileTabsDelegate(
                tabs: PublicProfileScreen.tabs,
                tab: _tab,
                background: p.background,
                onSelect: (t) => setState(() => _tab = t),
              ),
            ),
            ProfileGrid(username: profile.username, tab: _tab),
          ],
        ],
      ),
    );
  }
}
