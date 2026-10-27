import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/debug/profile-preview` — the real [ProfileScreen] (D57) with labelled
/// test data: `GET /me`, the counts and both grids are overridden, under
/// the app's bottom bar. The name carries "(test)" and the photos are the
/// dev-only preview set.
class ProfilePreviewScreen extends StatelessWidget {
  const new({super.key, this.edit = false});

  /// Shows [EditProfileScreen] (`/debug/profile-edit-preview`) instead.
  final bool edit;

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    final user = User(
      id: 'preview-user',
      email: 'preview@example.invalid',
      emailVerified: true,
      username: 'layla.test',
      displayName: ar ? 'ليلى (تجربة)' : 'Layla (test)',
      locale: ar ? 'ar' : 'en',
      role: UserRole.user,
      isPrivate: false,
      createdAt: DateTime.utc(2026),
      bio: ar
          ? 'نبذة تجريبية: موسيقى ورحلات وبث مباشر كل مساء #بيانات_اختبار'
          : 'Test bio: music, trips and a live stream every evening '
                '#test_data',
    );
    return ProviderScope(
      overrides: [
        meProvider.overrideWith((ref) => user),
        profileStatsProvider.overrideWith(
          (ref, username) => PublicProfile(
            id: user.id,
            username: username,
            displayName: user.displayName,
            avatarUrl: null,
            bio: user.bio,
            isPrivate: false,
            followerCount: 5600,
            followingCount: 91,
            isFollowing: false,
            isSelf: true,
            liveRoomId: null,
          ),
        ),
        profileGridProvider.overrideWith(
          (ref, key) => FeedItems([
            for (var i = 0; i < 9; i++)
              ProfileGridItem(
                cover: PreviewPhoto.enabled
                    ? PreviewPhotos.image(
                        key.tab == ProfileTab.posts
                            ? PreviewPhotoKind.landscape
                            : PreviewPhotoKind.portrait,
                        i,
                      )
                    : null,
                isVideo:
                    key.tab == ProfileTab.reels ||
                    i % 4 == 1 ||
                    (key.tab == ProfileTab.saved && i.isEven),
              ),
          ]),
        ),
      ],
      child: edit
          ? const EditProfileScreen()
          : Scaffold(
              body: const ProfileScreen(),
              bottomNavigationBar: KTabBar(
                currentIndex: AppRoutes.shellBranches.indexOf(
                  AppRoutes.profile,
                ),
                onSelect: (i) => context.go(AppRoutes.shellBranches[i]),
                items: shellTabItems(context.l10n),
              ),
            ),
    );
  }
}

/// `/debug/user-preview` — the real [PublicProfileScreen] (D60) with
/// labelled test data: a public creator who is live now and whom you do not
/// follow. Follow succeeds locally (no server).
class UserPreviewScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    final profile = PublicProfile(
      id: 'preview-host',
      username: 'omar.test',
      displayName: ar ? 'عمر (تجربة)' : 'Omar (test)',
      avatarUrl: null,
      bio: ar
          ? 'عازف عود، بث مباشر كل خميس #بيانات_اختبار'
          : 'Oud player, live every Thursday #test_data',
      isPrivate: false,
      followerCount: 12400,
      followingCount: 180,
      isFollowing: false,
      isSelf: false,
      liveRoomId: 'preview-room',
    );
    return ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_PreviewProfiles(profile)),
        // Re-created in this scope so it reads the preview repository.
        publicProfileProvider.overrideWith2(PublicProfileController.new),
        profileGridProvider.overrideWith(
          (ref, key) => FeedItems([
            for (var i = 0; i < 9; i++)
              ProfileGridItem(
                cover: PreviewPhoto.enabled
                    ? PreviewPhotos.image(
                        key.tab == ProfileTab.posts
                            ? PreviewPhotoKind.landscape
                            : PreviewPhotoKind.portrait,
                        i + 1,
                      )
                    : null,
                isVideo: key.tab == ProfileTab.reels,
              ),
          ]),
        ),
      ],
      child: PublicProfileScreen(username: profile.username),
    );
  }
}

/// Public profile and follow for the preview only (no server).
class _PreviewProfiles implements ProfileRepository {
  new(this.profile);

  PublicProfile profile;

  @override
  Future<PublicProfile> getProfile(String username) async => profile;

  Future<FollowState> _set({required bool following}) async {
    final count =
        profile.followerCount +
        (following == profile.isFollowing ? 0 : (following ? 1 : -1));
    profile = profile.copyWith(isFollowing: following, followerCount: count);
    return FollowState(isFollowing: following, followerCount: count);
  }

  @override
  Future<FollowState> follow(String username) => _set(following: true);

  @override
  Future<FollowState> unfollow(String username) => _set(following: false);
}
