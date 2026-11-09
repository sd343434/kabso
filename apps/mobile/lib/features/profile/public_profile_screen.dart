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
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/presentation/founder_moderation.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_actions.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_sections.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/users/:username` (D60): another user's public profile, from
/// `GET /users/{username}` (v1.3).
///
/// D218 (owner, after a reference: «بهذا التصميم حرفياً مع اضافة ميزاتنا»):
/// the top bar of before (back, the centred @username, the three dots —
/// owner: «ارجعهم مثل ما كانو»), then a cover (`coverUrl`, or a Kabso
/// gradient); the photo overlapping the cover (the live ring and «يبث
/// الآن» while live — a tap opens the room); the name (no
/// verification mark: the owner decides on one later); «N متابِع · N
/// متابَع» (the lists); the bio; the country and «انضم في <شهر سنة>»; the
/// links; a wide Follow pill (متابَع / تم الطلب / إلغاء الحظر) and a round
/// Message button; then our features — medals, family and relationship
/// (`ProfileBondsBlock`). Owner, later: the @username only in the top bar
/// (beside the name: room for a verification mark), the level badges right
/// under the name, no PK record pill. The words
/// «منشورات | ريلز | إعادات» over the 3-column grid (1 px gaps). Private
/// and blocked accounts keep their honest states. Before D218:
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
  static const Key watchLiveKey = ProfileCoverHeader.watchLiveKey;
  static const messageKey = Key('profile.public.message');
  static const moreKey = Key('profile.public.more');

  /// D278: the more button in the action row over the cover.
  static const dropdownKey = Key('profile.public.dropdown');
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
  static const Key coverKey = ProfileCoverHeader.coverKey;
  static const Key coverFallbackKey = ProfileCoverHeader.coverFallbackKey;
  static const unblockKey = Key('profile.public.unblock');
  static const blockedKey = Key('profile.public.blocked');
  static const Key factsKey = ProfileInfoBlock.factsKey;
  static const Key levelsKey = ProfileInfoBlock.levelsKey;

  static const List<ProfileTab> tabs = [
    ProfileTab.posts,
    ProfileTab.reels,
    ProfileTab.reposts,
  ];

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

enum _More { copy, mute, unmute, block, report, founder }

/// Asks before unfollowing [name] (the profile page and, D220, the person
/// card in a live): true when confirmed. D232: [live] asks in the live's
/// card style ([KLiveDialogCard]).
Future<bool> confirmUnfollow(
  BuildContext context,
  String name, {
  bool live = false,
}) async {
  final l10n = context.l10n;
  if (live) {
    return await showKLiveConfirm(
      context,
      title: l10n.profileUnfollowConfirm(name),
      confirmKey: PublicProfileScreen.unfollowKey,
      confirmLabel: l10n.homeUnfollowAuthor(name),
      cancelLabel: l10n.actionCancel,
    );
  }
  final unfollow = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Text(
              l10n.profileUnfollowConfirm(name),
              textAlign: TextAlign.center,
              style: sheet.textStyles.bodyStrong,
            ),
          ),
          ListTile(
            key: PublicProfileScreen.unfollowKey,
            title: Text(
              l10n.homeUnfollowAuthor(name),
              textAlign: TextAlign.center,
              style: TextStyle(color: sheet.palette.error),
            ),
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ],
      ),
    ),
  );
  return unfollow ?? false;
}

/// D175: asks before cancelling a pending follow request to [name] (the
/// profile page and the live room). True when the person confirms. D232:
/// [live] asks in the live's card style ([KLiveDialogCard]).
Future<bool> confirmCancelFollowRequest(
  BuildContext context,
  String name, {
  bool live = false,
}) async {
  final l10n = context.l10n;
  if (live) {
    return await showKLiveConfirm(
      context,
      title: l10n.profileCancelRequestConfirm(name),
      confirmKey: PublicProfileScreen.cancelRequestKey,
      confirmLabel: l10n.profileCancelRequest,
      cancelLabel: l10n.actionCancel,
    );
  }
  final cancel = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Text(
              l10n.profileCancelRequestConfirm(name),
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
  return cancel ?? false;
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  ProfileTab _tab = ProfileTab.posts;

  /// D278: the cover has scrolled out from under the top bar.
  bool _solid = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final solid = profileCoverScrolledAway(context, n.metrics);
    if (solid != _solid) setState(() => _solid = solid);
    return false;
  }

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
    if (await confirmCancelFollowRequest(context, profile.displayName)) {
      await _setFollowing(follow: false);
    }
  }

  Future<void> _confirmUnfollow(PublicProfile profile) async {
    if (await confirmUnfollow(context, profile.displayName) && mounted) {
      await _setFollowing(follow: false);
    }
  }

  /// D62: the three dots: copy the username; mute, block and report the
  /// account (CONVENTIONS §11.7). Copying the profile link waits for the
  /// production domain (B7) and is shown as "Coming soon".
  Future<void> _openMore(PublicProfile profile) async {
    final l10n = context.l10n;
    final name = profile.displayName.isEmpty
        ? profile.username
        : profile.displayName;
    // D311: «إجراءات المؤسس» for the app owner on anyone else (not an owner).
    final founder = founderActionsOffered(
      ref,
      targetIsSelf: profile.isSelf,
      targetIsOwner: profile.kabsoOwner,
    );
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
                if (founder)
                  FounderActionsTile(
                    onTap: () => Navigator.of(sheet).pop(_More.founder),
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
              staffId: profile.staffId,
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
      case _More.founder:
        final done = await showFounderActions(context, (
          id: profile.id,
          username: profile.username,
          name: name,
        ));
        // The profile reads again (a ban or a deletion hides it).
        if (done && mounted) {
          ref.invalidate(publicProfileProvider(profile.username));
        }
    }
  }

  /// D218: unblocks the account (the profile stays: its posts show again).
  Future<void> _unblock(PublicProfile profile) async {
    final l10n = context.l10n;
    try {
      await ref
          .read(safetyRepositoryProvider)
          .setBlocked(profile.username, blocked: false);
      ref.invalidate(publicProfileProvider(widget.username));
      if (mounted) {
        KSnack.success(context, l10n.safetyUnblocked(profile.displayName));
      }
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  /// D278: the action row over the cover — «متابعة» in Kabso red (or
  /// متابَع / تم الطلب / إلغاء الحظر), the chat button (the conversation)
  /// and the more button (the same sheet as the bar's dots); your own
  /// profile gets Edit profile. D316: «متابعة» / «مراسلة» pills and the
  /// round ⋯ under the centred header (the founder's page keeps D301).
  Widget _actions(PublicProfile profile) {
    final l10n = context.l10n;
    final p = context.palette;
    final quiet = ProfileCoverButtons.pill(context);
    final strong = ProfileCoverButtons.pillPrimary(context);
    if (profile.isSelf) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: quiet,
          onPressed: () => context.push(AppRoutes.editProfile),
          child: ProfileCoverButtons.label(l10n.profileEditShort),
        ),
      );
    }
    // D301 (§10.112.6): the app owner's page — «متابعة المؤسس» and «اقترح
    // ميزة / أبلغ عن موظف» (the follow of §10.6, styled for the page).
    if (profile.kabsoOwner && !profile.blockedByMe) {
      return OwnerVisitorActions(
        following: profile.isFollowing,
        requested: profile.followRequested,
        onFollow: profile.isFollowing
            ? () => _confirmUnfollow(profile)
            : profile.followRequested
            ? () => _confirmCancelRequest(profile)
            : () => _setFollowing(follow: true),
        more: ProfileCoverButtons.square(
          context: context,
          key: PublicProfileScreen.dropdownKey,
          tooltip: l10n.feedPostMore,
          icon: AppIcon(
            AppIcons.chevronDown,
            size: KMetrics.iconMd - 2,
            color: p.textPrimary,
          ),
          onPressed: () => _openMore(profile),
        ),
      );
    }
    final main = profile.blockedByMe
        ? FilledButton(
            key: PublicProfileScreen.unblockKey,
            style: strong,
            onPressed: () => _unblock(profile),
            child: ProfileCoverButtons.label(l10n.safetyUnblock),
          )
        : profile.isFollowing
        ? OutlinedButton(
            key: PublicProfileScreen.followKey,
            style: quiet,
            onPressed: () => _confirmUnfollow(profile),
            child: ProfileCoverButtons.label(l10n.liveFollowing),
          )
        : profile.followRequested
        // D175: a request to a private account waits for its answer.
        ? OutlinedButton(
            key: PublicProfileScreen.followKey,
            style: quiet,
            onPressed: () => _confirmCancelRequest(profile),
            child: ProfileCoverButtons.label(l10n.followRequested),
          )
        : FilledButton(
            key: PublicProfileScreen.followKey,
            style: strong,
            // D175: a private account gets a follow request (§10.47).
            onPressed: profile.canFollowOrRequest
                ? () => _setFollowing(follow: true)
                : null,
            child: ProfileCoverButtons.label(l10n.liveFollow),
          );
    // D316 (the owner's reference: «Message» / «Request» / ⋮): «متابعة»
    // and «مراسلة» as two equal pills, then the round ⋯ (the bar's sheet).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: main),
        if (!profile.blockedByMe) ...[
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: OutlinedButton(
              key: PublicProfileScreen.messageKey,
              style: quiet,
              onPressed: () => context.push(
                AppRoutes.chat(profile.username),
                extra: (
                  displayName: profile.displayName,
                  premiumTier: profile.premiumTier,
                ),
              ),
              child: ProfileCoverButtons.label(l10n.profileMessage),
            ),
          ),
        ],
        const SizedBox(width: KSpacing.sm),
        // D316: the page's only ⋯ (the bar has none): [_openMore] — copy,
        // mute, block, report (and what else that sheet offers). Found by
        // both [PublicProfileScreen.moreKey] (the bar's key before) and
        // [PublicProfileScreen.dropdownKey].
        KeyedSubtree(
          key: PublicProfileScreen.dropdownKey,
          child: ProfileCoverButtons.round(
            context: context,
            key: PublicProfileScreen.moreKey,
            tooltip: l10n.feedPostMore,
            onPressed: () => _openMore(profile),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(publicProfileProvider(widget.username));
    final body = switch (load) {
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
    };
    // D278: the bar of before (owner: «استخدم ازراري» — back, the @username
    // and the three dots) over the full-bleed cover: no background and the
    // buttons on translucent circles until the cover has scrolled away.
    final solid = _solid || load.value == null;
    // D316: on every profile but the founder's (no cover under the bar), the
    // bar's buttons and title take the theme's colours from the start.
    final faint = !(load.value?.kabsoOwner ?? false);
    final themed = solid || faint;
    return Scaffold(
      backgroundColor: p.background,
      extendBodyBehindAppBar: true,
      appBar: ProfileCoverBar(
        solid: solid,
        faint: faint,
        // D299d (owner: «اليوزر اجعله في أعلى الصفحة»): the @username at
        // the top over the cover too (D146: a premium one with its badge;
        // D283c: a staff account's «ID: Kabso01»).
        title: ProfileCoverHandle(
          solid: themed,
          start: faint,
          username: load.value?.username ?? widget.username,
          tier: load.value?.premiumTier,
          staffId: load.value?.staffId,
        ),
        // D316 (owner: «أزل الثلاث نقاط من الأعلى لأنها موجودة بجانب
        // مراسلة»): the bar's ⋯ only on the founder's page (D301 / D307) and
        // on your own page seen from here (it has no round ⋯); everyone
        // else's ⋯ is the round button beside «مراسلة» (the same sheet,
        // [_openMore], and the same [PublicProfileScreen.moreKey]).
        actions: [
          if (load.value case final value?
              when value.kabsoOwner || value.isSelf)
            IconButton(
              key: PublicProfileScreen.moreKey,
              tooltip: l10n.feedPostMore,
              // Needs the loaded profile (its id and whether it is you).
              onPressed: switch (load) {
                AsyncValue(:final value?) => () => _openMore(value),
                _ => null,
              },
              // D292: a plain glyph with a soft shadow over the cover.
              icon: ProfileCoverBar.glyph(
                solid: themed,
                child: AppIcon(
                  AppIcons.moreHoriz,
                  size: KMetrics.iconMd,
                  color: themed ? p.textPrimary : KPalette.dark.textPrimary,
                ),
              ),
            ),
        ],
      ),
      // Until the profile is read, the states sit under the bar.
      body: load.value == null
          ? Padding(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: body,
              ),
            )
          : body,
    );
  }

  static bool _notFound(Object error) => switch (toAppFailure(error)) {
    ServerFailure(code: ErrorCode.notFound) => true,
    _ => false,
  };

  Widget _body(PublicProfile profile) {
    final l10n = context.l10n;
    final p = context.palette;
    final locked = profile.locked;
    final hidden = locked || profile.blockedByMe;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () {
          ref
            ..invalidate(profileGridProvider)
            ..invalidate(ownerJourneyProvider(widget.username))
            ..invalidate(ownerOfficialPostsProvider(widget.username));
          return ref.refresh(publicProfileProvider(widget.username).future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // D278: the cover runs under the bar; the tabs pin under it.
            const ProfileCoverBarSpace(),
            SliverToBoxAdapter(
              child: ProfileCoverHeader(
                profile: profile,
                actions: _actions(profile),
                // D301: the owner's cover video, in the app's language.
                coverVideo: ownerCoverVideoFor(context, profile),
                // D121: the lists; a private account's are its followers'
                // only, so a locked profile keeps the counts plain.
                onOpenFollowers: hidden
                    ? null
                    : () =>
                          context.push(AppRoutes.userFollows(profile.username)),
                onOpenFollowing: hidden
                    ? null
                    : () => context.push(
                        AppRoutes.userFollows(
                          profile.username,
                          following: true,
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(child: ProfileInfoBlock(profile: profile)),
            // D301: «إعلانات رسمية» and «رحلة Kabso» on the owner's page.
            if (profile.kabsoOwner && !profile.blockedByMe) ...[
              SliverToBoxAdapter(
                child: OwnerProfileSections(profile: profile, own: false),
              ),
              // D307 follow-up: the announcements in full after «رحلة
              // Kabso».
              OfficialAnnouncementsFeed(username: profile.username, own: false),
            ],
            if (profile.blockedByMe)
              SliverToBoxAdapter(
                child: Padding(
                  key: PublicProfileScreen.blockedKey,
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
                  child: KEmptyState(
                    icon: Icons.block_rounded,
                    title: l10n.profileBlockedTitle,
                    message: l10n.profileBlockedBody,
                    compact: true,
                  ),
                ),
              )
            else if (locked)
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
            // D307 follow-up (owner: «في صفحة المؤسس لا تحتوي ريلز او بوست
            // او اي اعادة»): the founder's page ends with «رحلة Kabso».
            else if (profile.kabsoOwner)
              const SliverToBoxAdapter(child: SizedBox(height: KSpacing.xl))
            else ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: ProfileTabsDelegate(
                  tabs: PublicProfileScreen.tabs,
                  tab: _tab,
                  background: p.background,
                  text: true,
                  onSelect: (t) => setState(() => _tab = t),
                ),
              ),
              ProfileGrid(username: profile.username, tab: _tab),
            ],
          ],
        ),
      ),
    );
  }
}
