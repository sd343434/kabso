import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_record.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
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
/// الآن» while live — a tap opens the room); the name and the handle (no
/// verification mark: the owner decides on one later); «N متابِع · N
/// متابَع» (the lists); the bio; the country and «انضم في <شهر سنة>»; the
/// links; a wide Follow pill (متابَع / تم الطلب / إلغاء الحظر) and a round
/// Message button; then our features — levels and charm, medals, family,
/// relationship (`ProfileBondsBlock`) and the PK record; the words
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
  static const coverKey = Key('profile.public.cover');
  static const coverFallbackKey = Key('profile.public.cover.gradient');
  static const unblockKey = Key('profile.public.unblock');
  static const blockedKey = Key('profile.public.blocked');
  static const factsKey = Key('profile.public.facts');

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

/// D175: asks before cancelling a pending follow request to [name] (the
/// profile page and the live room). True when the person confirms.
Future<bool> confirmCancelFollowRequest(
  BuildContext context,
  String name,
) async {
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

  /// D218: the wide Follow pill (black in light, inverted in dark) and the
  /// round Message button; your own profile gets Edit profile.
  Widget _actions(PublicProfile profile) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KRadius.pill),
    );
    final quiet = OutlinedButton.styleFrom(
      foregroundColor: p.textPrimary,
      backgroundColor: p.background,
      side: BorderSide(color: p.borderStrong),
      shape: pill,
      textStyle: t.bodyStrong,
    );
    final strong = FilledButton.styleFrom(
      backgroundColor: p.textPrimary,
      foregroundColor: p.background,
      shape: pill,
      textStyle: t.bodyStrong,
    );
    if (profile.isSelf) {
      return SizedBox(
        height: KPublicProfile.buttonHeight,
        width: double.infinity,
        child: OutlinedButton(
          style: quiet,
          onPressed: () => context.push(AppRoutes.editProfile),
          child: Text(l10n.profileEditTitle),
        ),
      );
    }
    final main = profile.blockedByMe
        ? FilledButton(
            key: PublicProfileScreen.unblockKey,
            style: strong,
            onPressed: () => _unblock(profile),
            child: Text(l10n.safetyUnblock),
          )
        : profile.isFollowing
        ? OutlinedButton(
            key: PublicProfileScreen.followKey,
            style: quiet,
            onPressed: () => _confirmUnfollow(profile),
            child: Text(l10n.liveFollowing),
          )
        : profile.followRequested
        // D175: a request to a private account waits for its answer.
        ? OutlinedButton(
            key: PublicProfileScreen.followKey,
            style: quiet,
            onPressed: () => _confirmCancelRequest(profile),
            child: Text(l10n.followRequested),
          )
        : FilledButton(
            key: PublicProfileScreen.followKey,
            style: strong,
            // D175: a private account gets a follow request (§10.47).
            onPressed: profile.canFollowOrRequest
                ? () => _setFollowing(follow: true)
                : null,
            child: Text(l10n.liveFollow),
          );
    return SizedBox(
      height: KPublicProfile.buttonHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: main),
          if (!profile.blockedByMe) ...[
            const SizedBox(width: KSpacing.md),
            SizedBox(
              width: KPublicProfile.buttonHeight,
              child: Tooltip(
                message: l10n.profileMessage,
                child: OutlinedButton(
                  key: PublicProfileScreen.messageKey,
                  style: quiet.copyWith(
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    shape: const WidgetStatePropertyAll(CircleBorder()),
                  ),
                  onPressed: () => context.push(
                    AppRoutes.chat(profile.username),
                    extra: (
                      displayName: profile.displayName,
                      premiumTier: profile.premiumTier,
                    ),
                  ),
                  child: Semantics(
                    label: l10n.profileMessage,
                    child: AppIcon(
                      AppIcons.send,
                      size: KMetrics.iconMd - 2,
                      color: p.textPrimary,
                    ),
                  ),
                ),
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
    // Owner (after D218): «ارجعهم مثل ما كانو» — the bar of before D218:
    // back, the centred @username (a premium one with its badge) and the
    // three dots, on the page colour; the cover starts under it.
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
      body: body,
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
    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(profileGridProvider);
        return ref.refresh(publicProfileProvider(widget.username).future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _CoverHeader(profile: profile)),
          SliverToBoxAdapter(
            child: _ProfileInfo(
              profile: profile,
              actions: _actions(profile),
              // D121: the lists; a private account's are its followers'
              // only, so a locked profile keeps the counts plain.
              onOpenFollowers: hidden
                  ? null
                  : () => context.push(AppRoutes.userFollows(profile.username)),
              onOpenFollowing: hidden
                  ? null
                  : () => context.push(
                      AppRoutes.userFollows(profile.username, following: true),
                    ),
            ),
          ),
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
    );
  }
}

/// D218 geometry of the public profile (the owner's reference, right
/// phone; E at ≈0.81 px/dp, 393 dp wide assumed): the cover 140 dp (under
/// the restored top bar, owner after D218), the photo overlapping the cover
/// by half, 44 dp pill buttons.
abstract final class KPublicProfile {
  static const double coverHeight = 140;
  static const double buttonHeight = 44;
  static const double nameFont = 18;
  static const double factIcon = 16;
}

/// D218: the cover (or the Kabso gradient) under the top bar, and the photo
/// overlapping its lower edge at the reading start. (The reference's back
/// and ⋮ squares over the cover were removed: owner, «ارجعهم مثل ما كانو».)
class _CoverHeader extends StatelessWidget {
  const new({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    // Under the restored bar (owner, after D218): no status-bar inset here.
    const coverHeight = KPublicProfile.coverHeight;
    const avatarBox = KProfile.avatar + 2 * KMetrics.strokeLarge;
    final room = profile.liveRoomId;
    final live = room != null;
    final fallback = DecoratedBox(
      key: PublicProfileScreen.coverFallbackKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            KBrandColors.red700,
            KBrandColors.red500,
            KBrandColors.red400.withValues(alpha: 0.85),
          ],
        ),
      ),
    );
    return SizedBox(
      // While live, the ring's badge hangs under the photo.
      height:
          coverHeight + avatarBox / 2 + (live ? KMetrics.badgeHeight / 2 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverHeight,
            child: switch (profile.coverUrl) {
              final url? => Image.network(
                url,
                key: PublicProfileScreen.coverKey,
                fit: BoxFit.cover,
                semanticLabel: l10n.profileCoverOf(profile.displayName),
                errorBuilder: (_, _, _) => fallback,
              ),
              null => fallback,
            },
          ),
          PositionedDirectional(
            top: coverHeight - avatarBox / 2,
            start: KProfile.inset,
            child: Semantics(
              key: ProfileHeaderView.avatarKey,
              button: live,
              label: live ? l10n.profileWatchLive : null,
              // While live the photo is the way into the room (one label).
              excludeSemantics: live,
              child: GestureDetector(
                key: live ? PublicProfileScreen.watchLiveKey : null,
                onTap: live
                    ? () => context.push(AppRoutes.liveRoom(room))
                    : null,
                child: ProfileAvatar(
                  displayName: profile.displayName,
                  avatarUrl: profile.avatarUrl,
                  live: live,
                  cpFrame: cpWearsSpecialFrame(profile.cp),
                  agentCode: profile.rechargeAgentCode,
                  hostAgentCode: profile.hostAgentCode,
                  avatarFrame: profile.avatarFrame,
                  outline: p.background,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// D218: the name and handle, the counts, the bio, the country and the
/// month joined, the links, the buttons, then our features.
class _ProfileInfo extends StatelessWidget {
  const new({
    required this.profile,
    required this.actions,
    this.onOpenFollowers,
    this.onOpenFollowing,
  });

  final PublicProfile profile;
  final Widget actions;
  final VoidCallback? onOpenFollowers;
  final VoidCallback? onOpenFollowing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag();
    final bio = profile.bio;
    final arabic = locale.languageCode == 'ar';
    final country = KCountries.byCode(profile.country);
    final joined = switch (profile.joinedMonth?.split('-')) {
      [final y, final m]
          when int.tryParse(y) != null && int.tryParse(m) != null =>
        DateTime(int.parse(y), int.parse(m)),
      _ => null,
    };
    final muted = t.caption.copyWith(color: p.textSecondary, fontSize: 13);
    Widget count(int value, String label, VoidCallback? onTap, Key key) =>
        Semantics(
          key: key,
          button: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(KRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.xxs),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: KFormat.compact(value, l10n),
                      style: t.bodyStrong.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: label,
                      style: t.body.copyWith(color: p.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    Widget fact(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: KPublicProfile.factIcon, color: p.textSecondary),
        const SizedBox(width: KSpacing.xs),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
      ],
    );
    final agentCode = profile.rechargeAgentCode;
    final hostCode = profile.hostAgentCode;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KProfile.inset,
        KSpacing.sm,
        KProfile.inset,
        KSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The name, our badges and the handle on one line (they wrap).
          // No verification mark (owner, D218: decided later).
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KSpacing.sm,
            runSpacing: KSpacing.xxs,
            children: [
              Text(
                profile.displayName,
                key: const Key('profile.displayName'),
                style: t.title.copyWith(
                  color: p.textPrimary,
                  fontSize: KPublicProfile.nameFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (agentCode case final code?)
                RechargeAgentBadge(
                  key: ProfileHeaderView.agentBadgeKey,
                  code: code,
                ),
              if (hostCode case final code?)
                HostAgentBadge(
                  key: ProfileHeaderView.hostAgentBadgeKey,
                  code: code,
                ),
              if (rechargeBadgeShows(profile.rechargeBadge))
                RechargeTierBadge(
                  key: ProfileHeaderView.rechargeBadgeKey,
                  badge: profile.rechargeBadge,
                ),
              switch (profile.premiumTier) {
                final tier? => KSpecialUsername(
                  username: profile.username,
                  tier: tier,
                  height: 20,
                ),
                null => Text(KHandle.isolated(profile.username), style: muted),
              },
            ],
          ),
          ProfileFieldsLine(category: profile.category, gender: profile.gender),
          const SizedBox(height: KSpacing.xs),
          Wrap(
            key: ProfileScreen.statsKey,
            spacing: KSpacing.lg,
            children: [
              count(
                profile.followerCount,
                l10n.profileFollowerWord,
                onOpenFollowers,
                ProfileHeaderView.followersKey,
              ),
              count(
                profile.followingCount,
                l10n.profileFollowingWord,
                onOpenFollowing,
                ProfileHeaderView.followingKey,
              ),
            ],
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: KSpacing.xs),
            Text(bio, style: t.body.copyWith(color: p.textPrimary)),
          ],
          if (country != null || joined != null) ...[
            const SizedBox(height: KSpacing.sm),
            Wrap(
              key: PublicProfileScreen.factsKey,
              spacing: KSpacing.lg,
              runSpacing: KSpacing.xs,
              children: [
                if (country != null)
                  fact(
                    Icons.place_outlined,
                    '${KCountries.flag(country.code)} '
                    '${KCountries.name(country, arabic: arabic)}',
                  ),
                if (joined != null)
                  fact(
                    Icons.calendar_month_outlined,
                    l10n.profileJoined(
                      '${DateFormat.MMMM(tag).format(joined)} ${joined.year}',
                    ),
                  ),
              ],
            ),
          ],
          // D175: the links — on a private profile too (§10.47).
          ProfileLinksRow(links: profile.links, reportable: !profile.isSelf),
          const SizedBox(height: KSpacing.md),
          actions,
          // Our features (D218: nothing removed, each in a tidy row): the
          // levels and charm, the medals shown, family, relationship and
          // medals tiles; then the PK record.
          ProfileBondsBlock(
            levels: ProfileLevels(
              username: profile.isSelf ? null : profile.username,
              onOpen: profile.isSelf
                  ? () => context.push(AppRoutes.levels)
                  : null,
              padding: const EdgeInsetsDirectional.only(top: KSpacing.md),
            ),
            profile: profile,
          ),
          LivePkRecordLine(username: profile.username),
        ],
      ),
    );
  }
}
