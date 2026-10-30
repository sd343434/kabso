import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Profile geometry (D57, layout from the owner's reference; sizes on the
/// Kabso scale).
abstract final class KProfile {
  static const double inset = KSpacing.lg;
  static const double avatar = KSizes.avatarLg;

  /// The gap between grid cells.
  static const double gridGap = KMetrics.hairline;

  /// A reels cell is portrait; a posts cell is square.
  static const double reelAspect = 9 / 16;

  /// Header buttons (Edit profile, Follow, Watch live).
  static const double buttonHeight = KSizes.minTouchTarget - KSpacing.sm;
}

/// The signed-in user's own profile (D57), from `GET /me` plus the counts
/// of `GET /users/{username}`. D163 (owner): it opens from the Me hub
/// (`MeHubScreen`, the photo or the name) at [AppRoutes.myProfile]; the
/// level badge sits beside the name, and the family, relationship, medals,
/// bag and premium-username boxes (and the chosen medals) live in the hub
/// and the medals page instead:
///
/// - top bar: @username in the centre, Drafts and Settings at the end;
/// - the photo at the start with the Followers and Following counts beside
///   it (there is no posts count until a posts API exists), then the name
///   and the bio;
/// - a full-width "Edit profile" button (D58; the edit screen is read-only
///   until the contract lets `PATCH /me` save the name and bio);
/// - Posts, Reels, Reposts and Saved tabs (grid, reels, repost and
///   bookmark icons, an underline on the selected one) over a 3-column
///   grid of covers on the posts API (KL-060). Saved (D59) holds what you
///   saved; only you see it. Reels have no API before M2 and show their
///   honest "coming" state.
class ProfileScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const settingsButtonKey = Key('profile.settings');
  static const draftsButtonKey = Key('profile.drafts');
  static const editButtonKey = Key('profile.editButton');
  static const statsKey = Key('profile.stats');
  static const tabsKey = Key('profile.tabs');

  static Key tabKey(ProfileTab tab) => Key('profile.tab.${tab.name}');

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  ProfileTab _tab = ProfileTab.posts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final me = ref.watch(meProvider);
    final username =
        me.value?.username ?? ref.watch(currentUserProvider)?.username ?? '';
    // D146: the premium username's tier (the special-ID badge in the bar).
    final tier = me.hasValue
        ? me.value!.premiumTier
        : ref.watch(currentUserProvider)?.premiumTier;

    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        // PHASE1_1_SCREENS §5.4: the TopBar shows @username ("Profile" stays
        // the tab label).
        title: tier == null
            ? Text(
                l10n.profileUsername(username),
                key: const Key('profile.title'),
                textDirection: TextDirection.ltr,
                style: context.textStyles.title.copyWith(color: p.textPrimary),
              )
            : KSpecialUsername(
                key: const Key('profile.title'),
                username: username,
                tier: tier,
                height: 24,
              ),
        actions: [
          IconButton(
            key: ProfileScreen.draftsButtonKey,
            tooltip: l10n.draftsTitle,
            icon: Icon(
              Icons.drafts_outlined,
              size: KMetrics.iconMd,
              color: p.textPrimary,
            ),
            onPressed: () => context.push(AppRoutes.drafts),
          ),
          IconButton(
            key: ProfileScreen.settingsButtonKey,
            tooltip: l10n.settingsTitle,
            icon: AppIcon(
              AppIcons.settings,
              size: KMetrics.iconMd,
              color: p.textPrimary,
            ),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: switch (me) {
        // Keep showing the user while a pull-to-refresh is running.
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async {
            try {
              ref
                ..invalidate(meProvider)
                ..invalidate(profileStatsProvider(value.username))
                ..invalidate(profileGridProvider);
              await ref.read(meProvider.future);
            } on Object catch (e) {
              if (context.mounted) {
                KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
              }
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _OwnHeader(user: value)),
              SliverPersistentHeader(
                pinned: true,
                delegate: ProfileTabsDelegate(
                  tabs: ProfileTab.values,
                  tab: _tab,
                  background: p.background,
                  onSelect: (t) => setState(() => _tab = t),
                ),
              ),
              ProfileGrid(username: value.username, tab: _tab, own: true),
            ],
          ),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(meProvider),
        ),
        _ => const ProfileSkeleton(),
      },
    );
  }
}

class _OwnHeader extends ConsumerWidget {
  const new({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsLoad = ref.watch(profileStatsProvider(user.username));
    final stats = statsLoad.value;
    return ProfileHeaderView(
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      followers: stats?.followerCount,
      following: stats?.followingCount,
      // A failed count shows a dash, not a number, and not an endless
      // skeleton; pull to refresh retries.
      statsFailed: statsLoad.hasError && stats == null,
      // CP-018: the chosen medals and the family, relationship and medals
      // tiles come with the counts (`GET /users/{username}`).
      // D163: the level badge beside the name; the bond boxes moved to the
      // Me hub, the chosen medals to the medals page.
      nameTrailing: ProfileLevels(
        onOpen: () => context.push(AppRoutes.levels),
        padding: EdgeInsetsDirectional.zero,
      ),
      // D168 (owner: «اعرض الصورة بدون إطار»): the own profile page shows
      // the plain photo; the heart frame stays on the Me hub and, as the
      // couple's privilege others see (D112), on the public profile.
      onOpenFollowers: () => context.push(AppRoutes.userFollows(user.username)),
      onOpenFollowing: () =>
          context.push(AppRoutes.userFollows(user.username, following: true)),
      actions: SizedBox(
        height: KProfile.buttonHeight,
        child: OutlinedButton(
          key: ProfileScreen.editButtonKey,
          style: profileSecondaryButtonStyle(context),
          onPressed: () => context.push(AppRoutes.editProfile),
          child: Text(context.l10n.profileEditTitle),
        ),
      ),
    );
  }
}

/// The outlined grey button of profile headers (Edit profile, Following).
ButtonStyle profileSecondaryButtonStyle(BuildContext context) {
  final p = context.palette;
  return OutlinedButton.styleFrom(
    foregroundColor: p.textPrimary,
    backgroundColor: p.surface,
    side: BorderSide(color: p.border),
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KRadius.sm),
    ),
    textStyle: context.textStyles.bodyStrong,
  );
}

/// The header shared by the own and the public profile (D57/D60): the photo
/// at the reading start (with the live ring and badge while [live]; tapping
/// it then calls [onOpenLive]), the Followers and Following counts beside
/// it, the name, the bio, then [actions].
class ProfileHeaderView extends StatelessWidget {
  const new({
    required this.displayName,
    required this.actions,
    super.key,
    this.avatarUrl,
    this.bio,
    this.followers,
    this.following,
    this.statsFailed = false,
    this.live = false,
    this.onOpenLive,
    this.levels,
    this.nameTrailing,
    this.cpFrame = false,
    this.onOpenFollowers,
    this.onOpenFollowing,
  });

  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int? followers;
  final int? following;
  final bool statsFailed;
  final bool live;
  final VoidCallback? onOpenLive;
  final Widget actions;

  /// D72: the level badges under the name and bio (`ProfileLevels`).
  final Widget? levels;

  /// D163: shown beside the name on the same line (the own profile's level
  /// badge); it wraps under the name when the line is full.
  final Widget? nameTrailing;

  /// CP-021 (D112): the person's couple unlocked the Special Frame
  /// (`PublicProfile.cp.privileges`); the picture is drawn in the owner's
  /// heart frame. While [live], the live ring (which opens the live) wins.
  final bool cpFrame;

  /// D121: tapping the Followers / Following count opens the follow lists.
  final VoidCallback? onOpenFollowers;
  final VoidCallback? onOpenFollowing;

  static const avatarKey = Key('profile.avatar');
  static const followersKey = Key('profile.stat.followers');
  static const followingKey = Key('profile.stat.following');
  static const cpFrameKey = Key('profile.avatar.cpFrame');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final bio = this.bio;
    Widget stat(
      String label,
      int? value, {
      Key? key,
      VoidCallback? onTap,
      String? hint,
    }) => Expanded(
      child: Semantics(
        key: key,
        button: onTap != null,
        hint: onTap == null ? null : hint,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KRadius.sm),
          child: Column(
            children: [
              if (value == null && !statsFailed)
                const KSkeleton(width: KSpacing.xl)
              else
                Text(
                  value == null ? '\u2013' : KFormat.compact(value, l10n),
                  maxLines: 1,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body.copyWith(color: p.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
    final avatar = cpFrame && !live
        ? CpSpecialFrameAvatar(
            key: cpFrameKey,
            width: CpSpecialFrameAvatar.widthForAvatar(KProfile.avatar),
            name: displayName,
            imageUrl: avatarUrl,
          )
        : KAvatar(
            name: displayName,
            imageUrl: avatarUrl,
            size: KProfile.avatar,
            ring: live ? KAvatarRing.live : KAvatarRing.none,
          );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KProfile.inset,
        KSpacing.sm,
        KProfile.inset,
        KSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                key: avatarKey,
                button: live && onOpenLive != null,
                label: live ? l10n.profileWatchLive : null,
                // The live ring of KAvatar carries the LIVE badge.
                child: GestureDetector(
                  onTap: live ? onOpenLive : null,
                  child: avatar,
                ),
              ),
              const SizedBox(width: KSpacing.lg),
              Expanded(
                child: Row(
                  key: ProfileScreen.statsKey,
                  children: [
                    stat(
                      l10n.profileFollowers,
                      followers,
                      key: followersKey,
                      onTap: onOpenFollowers,
                      hint: l10n.profileOpenFollowers,
                    ),
                    stat(
                      l10n.profileFollowingCount,
                      following,
                      key: followingKey,
                      onTap: onOpenFollowing,
                      hint: l10n.profileOpenFollowing,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KSpacing.sm,
            children: [
              Text(
                displayName,
                key: const Key('profile.displayName'),
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
              ?nameTrailing,
            ],
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: KSpacing.xxs),
            Text(bio, style: t.body.copyWith(color: p.textPrimary)),
          ],
          ?levels,
          const SizedBox(height: KSpacing.md),
          actions,
        ],
      ),
    );
  }
}

/// The pinned tab bar of a profile: one icon per tab in [tabs].
class ProfileTabsDelegate extends SliverPersistentHeaderDelegate {
  const new({
    required this.tabs,
    required this.tab,
    required this.background,
    required this.onSelect,
  });

  final List<ProfileTab> tabs;
  final ProfileTab tab;
  final Color background;
  final ValueChanged<ProfileTab> onSelect;

  @override
  double get minExtent => KSizes.minTouchTarget;

  @override
  double get maxExtent => KSizes.minTouchTarget;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final l10n = context.l10n;
    final p = context.palette;
    Widget item(ProfileTab t, String outline, String filled, String label) {
      final selected = t == tab;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          inMutuallyExclusiveGroup: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            key: ProfileScreen.tabKey(t),
            onTap: () => onSelect(t),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? p.textPrimary : p.border,
                    width: selected ? KMetrics.stroke : KMetrics.hairline,
                  ),
                ),
              ),
              child: Center(
                child: AppIcon(
                  selected ? filled : outline,
                  size: KMetrics.iconMd,
                  color: selected ? p.textPrimary : p.textTertiary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      key: ProfileScreen.tabsKey,
      color: background,
      child: Row(
        children: [
          for (final t in tabs)
            switch (t) {
              ProfileTab.posts => item(
                t,
                AppIcons.grid,
                AppIcons.gridFilled,
                l10n.homeTabPosts,
              ),
              ProfileTab.reels => item(
                t,
                AppIcons.reels,
                AppIcons.reelsFilled,
                l10n.homeTabReels,
              ),
              ProfileTab.reposts => item(
                t,
                AppIcons.repost,
                AppIcons.repost,
                l10n.profileReposts,
              ),
              ProfileTab.saved => item(
                t,
                AppIcons.bookmark,
                AppIcons.bookmarkFilled,
                l10n.profileSaved,
              ),
            },
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(ProfileTabsDelegate old) =>
      old.tab != tab || old.background != background || old.tabs != tabs;
}

/// The selected tab's grid of [username], or its state. [own] picks the
/// copy ("Your posts…") of the own profile.
class ProfileGrid extends ConsumerWidget {
  const new({
    required this.username,
    required this.tab,
    super.key,
    this.own = false,
  });

  final String username;
  final ProfileTab tab;
  final bool own;

  static const gridKey = Key('profile.grid');
  static const loadMoreRetryKey = Key('profile.grid.retry');
  static Key cellKey(String postId) => PostGridCell.cellKey(postId);
  static const stateKey = Key('profile.gridState');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reels = tab == ProfileTab.reels;
    final saved = tab == ProfileTab.saved;
    // Saved mixes posts and reels: square cells, reels marked with play.
    final aspect = reels ? KProfile.reelAspect : 1.0;
    Widget state(String title, String body) => SliverToBoxAdapter(
      child: Padding(
        key: stateKey,
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
        child: KEmptyState(
          icon: switch (tab) {
            ProfileTab.posts => Icons.grid_on_rounded,
            ProfileTab.reels => Icons.smart_display_outlined,
            ProfileTab.reposts => Icons.repeat_rounded,
            ProfileTab.saved => Icons.bookmark_border_rounded,
          },
          title: title,
          message: body,
          compact: true,
        ),
      ),
    );
    Widget grid(int count, Widget Function(int) cell) => SliverGrid.builder(
      key: gridKey,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: KProfile.gridGap,
        crossAxisSpacing: KProfile.gridGap,
        childAspectRatio: aspect,
      ),
      itemCount: count,
      itemBuilder: (_, i) => cell(i),
    );
    final key = (username: username, tab: tab);
    // A reload (pull to refresh, a new page) keeps the cells on screen.
    return switch (ref.watch(profileGridProvider(key))) {
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      )
          when items.isNotEmpty =>
        SliverMainAxisGroup(
          slivers: [
            grid(items.length, (i) => PostGridCell(item: items[i])),
            if (hasMore)
              SliverToBoxAdapter(
                child: loadMoreError == null
                    ? PostGridLoadMore(
                        // A new element per page: each asks once.
                        key: ValueKey(items.length),
                        onVisible: () => ref
                            .read(profileGridPagesProvider(key).notifier)
                            .loadMore(),
                      )
                    : Center(
                        child: TextButton(
                          key: loadMoreRetryKey,
                          onPressed: () => ref
                              .read(profileGridPagesProvider(key).notifier)
                              .loadMore(),
                          child: Text(l10n.actionRetry),
                        ),
                      ),
              ),
          ],
        ),
      AsyncValue(value: FeedItems()) => state(
        switch (tab) {
          ProfileTab.posts => l10n.profileNoPosts,
          ProfileTab.reels => l10n.profileNoReels,
          ProfileTab.reposts => l10n.profileNoReposts,
          ProfileTab.saved => l10n.profileNoSaved,
        },
        switch (tab) {
          ProfileTab.saved => l10n.profileSavedEmptyBody,
          ProfileTab.reposts => l10n.profileRepostsEmptyBody,
          _ when own => l10n.profileGridEmptyBody,
          _ => l10n.profileOtherEmptyBody,
        },
      ),
      AsyncValue(value: FeedUnavailable()) => state(
        saved
            ? l10n.profileSavedComingTitle
            : (own
                  ? l10n.profileContentComingTitle
                  : l10n.profileOtherComingTitle),
        saved
            ? l10n.profileSavedComingBody
            : (own
                  ? l10n.profileContentComingBody
                  : l10n.profileOtherComingBody),
      ),
      AsyncError(:final error) => SliverToBoxAdapter(
        child: FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(profileGridProvider(key)),
        ),
      ),
      _ => grid(
        6,
        (_) => const KSkeleton(width: double.infinity, height: double.infinity),
      ),
    };
  }
}

/// Asks for the next page when it comes into view (built lazily near the
/// end of the grid).
class PostGridLoadMore extends StatefulWidget {
  const new({required this.onVisible, super.key});

  final VoidCallback onVisible;

  @override
  State<PostGridLoadMore> createState() => _PostGridLoadMoreState();
}

class _PostGridLoadMoreState extends State<PostGridLoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVisible());
  }

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(KSpacing.md),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// One cell of a posts grid (profile, hashtag, search): the cover, or the
/// text of a text-only post, with the pinned, gallery and video marks; a
/// real post opens its screen.
class PostGridCell extends StatelessWidget {
  const new({required this.item, super.key});

  final ProfileGridItem item;

  static Key cellKey(String postId) => Key('profile.grid.$postId');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final cover = item.cover;
    final text = item.text;
    final id = item.postId;
    final white = KPalette.dark.textPrimary;
    final cell = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          // A tint under the cover (and under a text-only post) so every
          // cell reads as a tile while its image loads or if it fails.
          color: p.surfaceOverlay,
          child: cover != null
              ? Image(
                  image: cover,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
                )
              : (text != null && text.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(KSpacing.sm),
                        child: Center(
                          child: Text(
                            text,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: context.textStyles.caption.copyWith(
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                      )
                    : null),
        ),
        if (item.isVideo || item.multiple || item.pinned)
          PositionedDirectional(
            top: KSpacing.xs,
            end: KSpacing.xs,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.pinned)
                  Icon(
                    Icons.push_pin_rounded,
                    size: KMetrics.iconSm,
                    color: cover == null ? p.textSecondary : white,
                  ),
                if (item.multiple)
                  Icon(
                    Icons.collections_rounded,
                    size: KMetrics.iconSm,
                    color: white,
                  ),
                if (item.isVideo)
                  AppIcon(AppIcons.play, size: KMetrics.iconSm, color: white),
              ],
            ),
          ),
      ],
    );
    if (id == null) return cell;
    return Semantics(
      button: true,
      label: [
        l10n.profileGridOpenPost,
        if (item.pinned) l10n.profileGridPinned,
        ?(text?.isEmpty ?? true ? null : text),
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        key: cellKey(id),
        onTap: () => context.push(AppRoutes.post(id)),
        child: cell,
      ),
    );
  }
}

/// Loading placeholder of a profile header.
class ProfileSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.loading,
      child: const Padding(
        padding: EdgeInsetsDirectional.all(KProfile.inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KSkeleton(height: KProfile.avatar, circle: true),
                SizedBox(width: KSpacing.lg),
                Expanded(child: KSkeleton(height: KSpacing.xxl)),
              ],
            ),
            SizedBox(height: KSpacing.md),
            KSkeleton(width: 140),
            SizedBox(height: KSpacing.md),
            KSkeleton(height: 40),
          ],
        ),
      ),
    );
  }
}
